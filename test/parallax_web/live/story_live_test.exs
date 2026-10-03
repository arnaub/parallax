defmodule ParallaxWeb.StoryLiveTest do
  use ParallaxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Parallax.Feeds
  alias Parallax.Repo
  alias Parallax.Stories.OutletFraming
  alias Parallax.Stories.Perspective
  alias Parallax.Stories.Story
  alias Parallax.Stories.Synthesis

  defp insert_story!(attrs) do
    defaults = %{
      title: "A story",
      description: "A short description",
      last_coverage_at: ~U[2024-01-01 00:00:00Z]
    }

    Story |> struct(Map.merge(defaults, attrs)) |> Repo.insert!()
  end

  defp insert_outlet! do
    {:ok, outlet} =
      Feeds.create_outlet(%{
        name: "Example Outlet",
        homepage_url: "https://example.com",
        feed_url: "https://example.com/feed.xml",
        language: "en"
      })

    outlet
  end

  test "falls back to the story's description when there's no synthesis yet", %{
    conn: conn
  } do
    story =
      insert_story!(%{title: "A story", description: "A short description"})

    {:ok, _view, html} = live(conn, ~p"/stories/#{story.id}")

    assert html =~ "A story"
    assert html =~ "A short description"
    assert html =~ "hasn&#39;t been generated"
  end

  test "renders the full synthesis, grouping outlet framings by perspective", %{
    conn: conn
  } do
    story = insert_story!(%{})
    outlet = insert_outlet!()

    synthesis =
      %Synthesis{}
      |> Synthesis.changeset(%{
        story_id: story.id,
        started: "How it began",
        current_state: "Where it stands",
        implications: "Why it matters"
      })
      |> Repo.insert!()

    perspective =
      %Perspective{}
      |> Perspective.changeset(%{
        synthesis_id: synthesis.id,
        label: "Government",
        description: "Argues for the decree"
      })
      |> Repo.insert!()

    %OutletFraming{}
    |> OutletFraming.changeset(%{
      synthesis_id: synthesis.id,
      outlet_id: outlet.id,
      perspective_id: perspective.id,
      framing: "Supportive framing"
    })
    |> Repo.insert!()

    {:ok, _view, html} = live(conn, ~p"/stories/#{story.id}")

    assert html =~ "How it began"
    assert html =~ "Where it stands"
    assert html =~ "Why it matters"
    assert html =~ "Government"
    assert html =~ "Example Outlet"
    assert html =~ "Supportive framing"
  end

  test "raises for an unknown story id", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/stories/999999")
    end
  end
end
