defmodule Mix.Tasks.Feeds.Poll do
  @moduledoc """
  Polls every outlet once and prints a summary.

      mix feeds.poll

  For fetching on demand during development — the `Feeds.Poller`
  process itself waits a full interval before its first automatic poll.
  """
  @shortdoc "Polls every outlet once"

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    Parallax.Feeds.poll_all_outlets()
    |> Enum.each(fn {outlet_id, result} -> print_result(outlet_id, result) end)
  end

  defp print_result(outlet_id, {:ok, new_count}) do
    Mix.shell().info("outlet #{outlet_id}: #{new_count} new")
  end

  defp print_result(outlet_id, {:error, reason}) do
    Mix.shell().error("outlet #{outlet_id}: #{inspect(reason)}")
  end
end
