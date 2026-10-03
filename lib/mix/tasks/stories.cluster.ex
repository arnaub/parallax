defmodule Mix.Tasks.Stories.Cluster do
  @moduledoc """
  Runs the daily Story pipeline once — clustering, then synthesis — and
  prints a summary.

      mix stories.cluster

  For running on demand during development — `Stories.Scheduler` itself
  waits a full day before its first automatic run.
  """
  @shortdoc "Clusters Coverage into Stories and synthesizes once"

  use Mix.Task

  alias Parallax.Stories

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    print_cluster_summary(Stories.cluster_unclustered_coverage())
    print_synthesis_summary(Stories.synthesize_stories_with_new_coverage())
  end

  defp print_cluster_summary(results) do
    matched = Enum.count(results, &match?({:ok, :matched}, &1))
    new_stories = Enum.count(results, &match?({:ok, :new_story}, &1))
    irrelevant = Enum.count(results, &match?({:ok, :irrelevant}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    Mix.shell().info(
      "clustered #{length(results)} items: #{matched} matched, " <>
        "#{new_stories} new stories, #{irrelevant} irrelevant, #{failed} failed"
    )
  end

  defp print_synthesis_summary(results) do
    synthesized = Enum.count(results, &match?({:ok, :synthesized}, &1))
    no_coverage = Enum.count(results, &match?({:ok, :no_coverage}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    Mix.shell().info(
      "synthesized #{synthesized} of #{length(results)} stories needing it, " <>
        "#{no_coverage} had no coverage to synthesize from, #{failed} failed"
    )
  end
end
