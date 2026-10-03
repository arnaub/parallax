defmodule Parallax.Feeds do
  @moduledoc """
  Outlets and the Coverage ingested from their RSS/Atom feeds.
  """

  import Ecto.Query

  alias Parallax.Feeds.Coverage
  alias Parallax.Feeds.Fetcher
  alias Parallax.Feeds.Outlet
  alias Parallax.Repo

  require Logger

  @max_concurrency 5

  @doc "All outlets, alphabetical by name."
  def list_outlets do
    Outlet |> order_by(asc: :name) |> Repo.all()
  end

  @doc "Creates an outlet. Used by priv/repo/seeds.exs."
  def create_outlet(attrs) do
    %Outlet{} |> Outlet.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Coverage newest first, limited to `:limit` (default 30), with its
  Outlet preloaded. Sorts by published_at, falling back to inserted_at
  when a feed omitted the date — plain `order_by(desc: :published_at)`
  would otherwise put undated items first in Postgres, wrongly looking
  newest.
  """
  def list_coverage(opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)

    from(c in Coverage,
      order_by: [desc: coalesce(c.published_at, c.inserted_at)],
      limit: ^limit,
      preload: :outlet
    )
    |> Repo.all()
  end

  @doc "Coverage never screened for relevance yet, oldest first, with its Outlet preloaded."
  def list_unclustered_coverage do
    from(c in Coverage,
      where: is_nil(c.relevant),
      order_by: [asc: coalesce(c.published_at, c.inserted_at)],
      preload: :outlet
    )
    |> Repo.all()
  end

  @doc "Assigns a Coverage item to a Story, marking it relevant."
  def assign_story(%Coverage{} = coverage, story_id) do
    coverage |> Coverage.story_changeset(story_id) |> Repo.update()
  end

  @doc "Marks a Coverage item as screened and not significant enough for a Story."
  def mark_irrelevant(%Coverage{} = coverage) do
    coverage |> Coverage.irrelevant_changeset() |> Repo.update()
  end

  @doc """
  A Story's linked Coverage, oldest first, with its Outlet preloaded.
  `opts[:since]` limits to Coverage attached after that time — used to
  find what's new since a Story's last synthesis.
  """
  def list_coverage_by_story(story_id, opts \\ []) do
    from(c in Coverage,
      where: c.story_id == ^story_id,
      order_by: [asc: c.inserted_at],
      preload: :outlet
    )
    |> since_filter(Keyword.get(opts, :since))
    |> Repo.all()
  end

  defp since_filter(query, nil), do: query

  defp since_filter(query, since) do
    from(c in query, where: c.inserted_at > ^since)
  end

  @doc """
  Fetches one outlet's feed and stores any Coverage not already seen,
  deduped on (outlet_id, dedup_key). Returns the count of newly stored
  items, or an error if the fetch/parse itself failed.
  """
  @spec poll_outlet(Outlet.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def poll_outlet(%Outlet{} = outlet) do
    case Fetcher.fetch(outlet.feed_url) do
      {:ok, items} -> {:ok, store_new_coverage(outlet, items)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Polls every outlet concurrently. One outlet failing (fetch error or
  task timeout) is logged and doesn't stop the others. Returns
  `%{outlet_id => {:ok, new_count} | {:error, reason}}`.
  """
  @spec poll_all_outlets() :: %{
          integer() => {:ok, non_neg_integer()} | {:error, term()}
        }
  def poll_all_outlets do
    outlets = list_outlets()

    outlets
    |> Task.async_stream(&poll_outlet/1,
      max_concurrency: @max_concurrency,
      on_timeout: :kill_task
    )
    |> Enum.zip(outlets)
    |> Map.new(fn {task_result, outlet} ->
      {outlet.id, log_and_return(outlet, task_result)}
    end)
  end

  defp log_and_return(outlet, {:ok, poll_result}),
    do: log_poll_result(outlet, poll_result)

  defp log_and_return(outlet, {:exit, reason}),
    do: log_poll_result(outlet, {:error, reason})

  defp log_poll_result(outlet, {:error, reason} = result) do
    Logger.warning(
      "Feeds.poll_outlet failed for #{outlet.name}: #{inspect(reason)}"
    )

    result
  end

  defp log_poll_result(_outlet, result), do: result

  defp store_new_coverage(outlet, items) do
    items
    |> Enum.map(&to_coverage_attrs(outlet, &1))
    |> Enum.count(&insert_new_coverage?/1)
  end

  defp to_coverage_attrs(outlet, item) do
    %{
      outlet_id: outlet.id,
      dedup_key: item.guid || item.url,
      url: item.url,
      title: item.title,
      summary: item.summary,
      published_at: item.published_at
    }
  end

  defp insert_new_coverage?(attrs) do
    case %Coverage{} |> Coverage.changeset(attrs) |> Repo.insert() do
      {:ok, _coverage} -> true
      {:error, changeset} -> handle_insert_error(changeset)
    end
  end

  @dedup_constraint "coverage_outlet_id_dedup_key_index"

  defp handle_insert_error(changeset) do
    if duplicate_conflict?(changeset) do
      false
    else
      Logger.warning(
        "Feeds: skipped an invalid Coverage item: #{inspect(changeset.errors)}"
      )

      false
    end
  end

  defp duplicate_conflict?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {_message, opts}} ->
      Keyword.get(opts, :constraint_name) == @dedup_constraint
    end)
  end
end
