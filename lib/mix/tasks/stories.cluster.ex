defmodule Mix.Tasks.Stories.Cluster do
  @moduledoc """
  Clusters every unclustered Coverage item into a Story once, and
  prints a summary.

      mix stories.cluster

  For running on demand during development — `Stories.Scheduler` itself
  waits a full day before its first automatic run.
  """
  @shortdoc "Clusters unclustered Coverage into Stories once"

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    results = Parallax.Stories.cluster_unclustered_coverage()

    matched = Enum.count(results, &match?({:ok, :matched}, &1))
    new_stories = Enum.count(results, &match?({:ok, :new_story}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    Mix.shell().info(
      "processed #{length(results)} items: #{matched} matched, " <>
        "#{new_stories} new stories, #{failed} failed"
    )
  end
end
