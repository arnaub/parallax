defmodule Parallax.Stories do
  @moduledoc """
  Stories: long-running situations that group significant Coverage
  across outlets and languages, screened and matched via an LLM.
  """

  import Ecto.Query

  alias Parallax.Feeds
  alias Parallax.Repo
  alias Parallax.Stories.Matcher
  alias Parallax.Stories.OutletFraming
  alias Parallax.Stories.Perspective
  alias Parallax.Stories.Story
  alias Parallax.Stories.Synthesis
  alias Parallax.Stories.Synthesizer

  require Logger

  @candidate_limit 50
  @default_call_interval_ms :timer.seconds(13)
  @initial_sample_per_outlet 3
  @initial_sample_total_cap 25

  @doc "Stories newest-active first, optionally limited via :limit."
  def list_stories(opts \\ []) do
    Story
    |> order_by(desc: :last_coverage_at)
    |> maybe_limit(Keyword.get(opts, :limit))
    |> Repo.all()
  end

  @doc "Fetches a Story by id, raising if it doesn't exist."
  def get_story!(id), do: Repo.get!(Story, id)

  @doc """
  A Story's newest synthesis, with its perspectives and outlet framings
  (and each framing's outlet) preloaded, or nil if none exists yet.
  """
  def latest_synthesis(story_id) do
    from(s in Synthesis,
      where: s.story_id == ^story_id,
      order_by: [desc: s.inserted_at],
      limit: 1,
      preload: [:perspectives, outlet_framings: :outlet]
    )
    |> Repo.one()
  end

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit), do: limit(query, ^limit)

  @doc """
  Screens and matches every unscreened Coverage item, sequentially and
  paced below Gemini's rate limit — every call hits the same endpoint,
  and this is an un-urgent daily job, so there's no benefit to
  concurrency here. One item's failure is logged and skipped; it stays
  unscreened and is retried on the next run. An item judged not
  significant enough is marked irrelevant and never retried.
  """
  @spec cluster_unclustered_coverage() :: [
          {:ok, :matched | :new_story | :irrelevant} | {:error, term()}
        ]
  def cluster_unclustered_coverage do
    Feeds.list_unclustered_coverage() |> Enum.map(&cluster_one/1)
  end

  defp cluster_one(coverage) do
    Process.sleep(call_interval_ms())
    candidates = list_stories(limit: @candidate_limit)

    case Matcher.match(coverage, candidates) do
      :irrelevant ->
        mark_irrelevant(coverage)

      {:match, story_id} ->
        attach(coverage, story_id)

      {:new, title, description} ->
        start_new_story(coverage, title, description)

      {:error, reason} ->
        log_and_skip(coverage, reason)
    end
  rescue
    error -> log_and_skip(coverage, error)
  end

  defp call_interval_ms do
    Application.get_env(
      :parallax,
      :stories_call_interval_ms,
      @default_call_interval_ms
    )
  end

  defp mark_irrelevant(coverage) do
    {:ok, _coverage} = Feeds.mark_irrelevant(coverage)
    {:ok, :irrelevant}
  end

  defp attach(coverage, story_id) do
    Repo.transaction(fn ->
      story = Repo.get!(Story, story_id)
      {:ok, _coverage} = Feeds.assign_story(coverage, story.id)
      bump_last_coverage_at(story, coverage)
    end)

    {:ok, :matched}
  end

  defp start_new_story(coverage, title, description) do
    Repo.transaction(fn ->
      {:ok, story} =
        create_story(title, description, coverage_timestamp(coverage))

      {:ok, _coverage} = Feeds.assign_story(coverage, story.id)
    end)

    {:ok, :new_story}
  end

  defp create_story(title, description, last_coverage_at) do
    %Story{}
    |> Story.changeset(%{
      title: title,
      description: description,
      last_coverage_at: last_coverage_at
    })
    |> Repo.insert()
  end

  defp bump_last_coverage_at(story, coverage) do
    timestamp = coverage_timestamp(coverage)

    if DateTime.compare(timestamp, story.last_coverage_at) == :gt do
      story |> Story.changeset(%{last_coverage_at: timestamp}) |> Repo.update!()
    else
      story
    end
  end

  defp coverage_timestamp(coverage),
    do: coverage.published_at || coverage.inserted_at

  defp log_and_skip(coverage, reason) do
    Logger.warning(
      "Stories.cluster_one failed for coverage #{coverage.id}: #{inspect(reason)}"
    )

    {:error, reason}
  end

  @doc """
  Builds a new synthesis version for every Story whose Coverage changed
  since its last synthesis (or has none yet). Same pacing and
  failure-isolation philosophy as clustering: one Story's failure is
  logged and skipped, retried on the next run.
  """
  @spec synthesize_stories_with_new_coverage() :: [
          {:ok, :synthesized | :no_coverage} | {:error, term()}
        ]
  def synthesize_stories_with_new_coverage do
    stories_needing_synthesis() |> Enum.map(&synthesize_one/1)
  end

  # "Needs synthesis" = no synthesis exists yet, or Coverage attached
  # since the last one. A plain Postgres DISTINCT ON (via `distinct:`
  # paired with a matching `order_by`) picks each Story's single most
  # recent synthesis to compare against.
  defp stories_needing_synthesis do
    latest_per_story =
      from(s in Synthesis,
        distinct: s.story_id,
        order_by: [asc: s.story_id, desc: s.inserted_at],
        select: %{story_id: s.story_id, generated_at: s.inserted_at}
      )

    from(story in Story,
      left_join: synth in subquery(latest_per_story),
      on: synth.story_id == story.id,
      where:
        is_nil(synth.generated_at) or
          story.last_coverage_at > synth.generated_at,
      select: story
    )
    |> Repo.all()
  end

  defp synthesize_one(story) do
    previous = latest_synthesis(story.id)
    coverage_items = coverage_for_synthesis(story, previous)
    synthesize_with_coverage(story, previous, coverage_items)
  rescue
    error -> log_and_skip_synthesis(story, error)
  end

  # Nothing to synthesize from — a Story can reach here with no linked
  # Coverage (e.g. manually seeded). Skip without calling Gemini rather
  # than asking it to fabricate content from nothing.
  defp synthesize_with_coverage(_story, _previous, []), do: {:ok, :no_coverage}

  defp synthesize_with_coverage(story, previous, coverage_items) do
    Process.sleep(call_interval_ms())

    case Synthesizer.synthesize(story, previous, coverage_items) do
      {:ok, result} -> {:ok, store_synthesis(story, result)}
      {:error, reason} -> log_and_skip_synthesis(story, reason)
    end
  end

  defp coverage_for_synthesis(story, nil) do
    story.id
    |> Feeds.list_coverage_by_story()
    |> cap_per_outlet(@initial_sample_per_outlet, @initial_sample_total_cap)
  end

  defp coverage_for_synthesis(story, previous) do
    Feeds.list_coverage_by_story(story.id, since: previous.inserted_at)
  end

  defp cap_per_outlet(coverage_items, per_outlet, total_cap) do
    coverage_items
    |> Enum.group_by(& &1.outlet_id)
    |> Enum.flat_map(fn {_outlet_id, items} ->
      items
      |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
      |> Enum.take(per_outlet)
    end)
    |> Enum.take(total_cap)
  end

  defp store_synthesis(story, result) do
    Repo.transaction(fn ->
      {:ok, synthesis} = create_synthesis(story, result)
      perspective_ids = create_perspectives(synthesis, result.perspectives)
      create_outlet_framings(synthesis, result.outlet_framings, perspective_ids)
    end)

    :synthesized
  end

  defp create_synthesis(story, result) do
    %Synthesis{}
    |> Synthesis.changeset(%{
      story_id: story.id,
      started: result.started,
      current_state: result.current_state,
      implications: result.implications
    })
    |> Repo.insert()
  end

  defp create_perspectives(synthesis, perspectives) do
    Map.new(perspectives, fn perspective ->
      {:ok, inserted} =
        %Perspective{}
        |> Perspective.changeset(
          Map.put(perspective, :synthesis_id, synthesis.id)
        )
        |> Repo.insert()

      {perspective.label, inserted.id}
    end)
  end

  defp create_outlet_framings(synthesis, outlet_framings, perspective_ids) do
    Enum.each(outlet_framings, fn framing ->
      %OutletFraming{}
      |> OutletFraming.changeset(%{
        synthesis_id: synthesis.id,
        outlet_id: framing.outlet_id,
        perspective_id: Map.get(perspective_ids, framing.perspective_label),
        framing: framing.framing
      })
      |> Repo.insert!()
    end)
  end

  defp log_and_skip_synthesis(story, reason) do
    Logger.warning(
      "Stories.synthesize_one failed for story #{story.id}: #{inspect(reason)}"
    )

    {:error, reason}
  end
end
