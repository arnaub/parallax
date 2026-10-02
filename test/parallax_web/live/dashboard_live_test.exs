defmodule ParallaxWeb.DashboardLiveTest do
  use ParallaxWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Parallax.Feeds
  alias Parallax.Feeds.Coverage

  defp create_outlet! do
    {:ok, outlet} =
      Feeds.create_outlet(%{
        name: "Example Outlet",
        homepage_url: "https://example.com",
        feed_url: "https://example.com/feed.xml",
        language: "en"
      })

    outlet
  end

  defp insert_coverage!(outlet, attrs) do
    defaults = %{
      outlet_id: outlet.id,
      dedup_key: "key-#{System.unique_integer([:positive])}",
      url: "https://example.com/story",
      title: "A story",
      summary: "A summary",
      published_at: ~U[2024-01-01 00:00:00Z],
      inserted_at: ~U[2024-01-01 00:00:00Z],
      updated_at: ~U[2024-01-01 00:00:00Z]
    }

    Coverage |> struct(Map.merge(defaults, attrs)) |> Parallax.Repo.insert!()
  end

  test "shows an empty-state message when there's no coverage", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "No coverage yet"
  end

  test "renders coverage items newest first", %{conn: conn} do
    outlet = create_outlet!()

    insert_coverage!(outlet, %{
      title: "Older story",
      url: "https://example.com/older",
      published_at: ~U[2024-01-01 00:00:00Z]
    })

    insert_coverage!(outlet, %{
      title: "Newer story",
      url: "https://example.com/newer",
      published_at: ~U[2024-06-01 00:00:00Z]
    })

    {:ok, _view, html} = live(conn, ~p"/")

    refute html =~ "No coverage yet"
    assert html =~ "Example Outlet"
    assert html =~ ~s(href="https://example.com/newer")
    assert html =~ ~s(href="https://example.com/older")

    newer_index = :binary.match(html, "Newer story") |> elem(0)
    older_index = :binary.match(html, "Older story") |> elem(0)
    assert newer_index < older_index
  end
end
