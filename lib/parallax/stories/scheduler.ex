defmodule Parallax.Stories.Scheduler do
  @moduledoc """
  Runs the daily Story pipeline — clustering, then synthesis — once a
  day, independent of the hourly RSS poller. Waits a full interval
  before its first run — use `mix stories.cluster` to run on demand
  instead.
  """

  use GenServer

  alias Parallax.Stories

  @interval :timer.hours(24)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_next_run()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cluster, state) do
    Stories.cluster_unclustered_coverage()
    Stories.synthesize_stories_with_new_coverage()
    schedule_next_run()
    {:noreply, state}
  end

  defp schedule_next_run do
    Process.send_after(self(), :cluster, @interval)
  end
end
