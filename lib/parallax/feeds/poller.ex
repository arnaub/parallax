defmodule Parallax.Feeds.Poller do
  @moduledoc """
  Polls every outlet on a fixed interval. Waits a full interval before
  its first poll — use `mix feeds.poll` to fetch on demand instead.
  """

  use GenServer

  alias Parallax.Feeds

  @poll_interval :timer.hours(1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_next_poll()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    Feeds.poll_all_outlets()
    schedule_next_poll()
    {:noreply, state}
  end

  defp schedule_next_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end
