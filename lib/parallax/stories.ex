defmodule Parallax.Stories do
  @moduledoc """
  Stories: long-running situations that group significant Coverage
  across outlets and languages, screened and matched via an LLM.
  """

  import Ecto.Query

  alias Parallax.Feeds
  alias Parallax.Repo
  alias Parallax.Stories.Matcher
  alias Parallax.Stories.Story

  require Logger

  @candidate_limit 50
  @default_call_interval_ms :timer.seconds(13)

  @doc "Stories newest-active first, optionally limited via :limit."
  def list_stories(opts \\ []) do
    Story
    |> order_by(desc: :last_coverage_at)
    |> maybe_limit(Keyword.get(opts, :limit))
    |> Repo.all()
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
end
