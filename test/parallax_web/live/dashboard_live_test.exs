defmodule ParallaxWeb.DashboardLiveTest do
  use ParallaxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Parallax.Stories.Story

  defp insert_story!(attrs) do
    defaults = %{
      title: "A story",
      description: "A description",
      last_coverage_at: ~U[2024-01-01 00:00:00Z]
    }

    Story
    |> struct(Map.merge(defaults, attrs))
    |> Parallax.Repo.insert!()
  end

  test "shows an empty-state message when there are no stories", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "No stories yet"
  end

  test "renders stories newest-active first", %{conn: conn} do
    insert_story!(%{
      title: "Older story",
      description: "The older description",
      last_coverage_at: ~U[2024-01-01 00:00:00Z]
    })

    insert_story!(%{
      title: "Newer story",
      description: "The newer description",
      last_coverage_at: ~U[2024-06-01 00:00:00Z]
    })

    {:ok, _view, html} = live(conn, ~p"/")

    refute html =~ "No stories yet"
    assert html =~ "The newer description"
    assert html =~ "The older description"

    newer_index = :binary.match(html, "Newer story") |> elem(0)
    older_index = :binary.match(html, "Older story") |> elem(0)
    assert newer_index < older_index
  end

  test "story cards link to the story's detail page", %{conn: conn} do
    story = insert_story!(%{title: "A story"})

    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ ~s(href="/stories/#{story.id}")
  end
end
