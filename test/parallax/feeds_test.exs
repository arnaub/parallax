defmodule Parallax.FeedsTest do
  use Parallax.DataCase, async: true

  alias Parallax.Feeds
  alias Parallax.Feeds.Coverage
  alias Parallax.Feeds.Fetcher

  defp insert_coverage!(outlet, attrs) do
    defaults = %{
      outlet_id: outlet.id,
      dedup_key: "key-#{System.unique_integer([:positive])}",
      url: "https://example.com/#{System.unique_integer([:positive])}",
      title: "Title",
      inserted_at: ~U[2024-01-01 00:00:00Z],
      updated_at: ~U[2024-01-01 00:00:00Z]
    }

    Coverage |> struct(Map.merge(defaults, attrs)) |> Repo.insert!()
  end

  defp outlet_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{
      name: "Example Outlet",
      homepage_url: "https://example.com",
      feed_url: "https://example.com/feed.xml",
      language: "en"
    })
  end

  defp create_outlet!(overrides \\ %{}) do
    {:ok, outlet} = Feeds.create_outlet(outlet_attrs(overrides))
    outlet
  end

  defp stub_feed(items) do
    Req.Test.stub(Fetcher, fn conn -> Req.Test.text(conn, items) end)
  end

  describe "create_outlet/1" do
    test "requires name, homepage_url, feed_url, and language" do
      assert {:error, changeset} = Feeds.create_outlet(%{})

      assert %{
               name: ["can't be blank"],
               homepage_url: ["can't be blank"],
               feed_url: ["can't be blank"],
               language: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "enforces feed_url uniqueness" do
      create_outlet!()

      assert {:error, changeset} = Feeds.create_outlet(outlet_attrs())
      assert %{feed_url: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "poll_outlet/1" do
    test "stores new Coverage from the feed" do
      outlet = create_outlet!()

      stub_feed("""
      <rss version="2.0"><channel>
        <item>
          <title>First story</title>
          <link>https://example.com/first</link>
          <guid>guid-1</guid>
          <pubDate>Wed, 02 Oct 2024 10:00:00 GMT</pubDate>
          <description>Summary</description>
        </item>
      </channel></rss>
      """)

      assert {:ok, 1} = Feeds.poll_outlet(outlet)
      assert [coverage] = Feeds.list_coverage()
      assert coverage.title == "First story"
      assert coverage.dedup_key == "guid-1"
    end

    test "polling the same feed twice doesn't duplicate items with a guid" do
      outlet = create_outlet!()

      stub_feed("""
      <rss version="2.0"><channel>
        <item>
          <title>First story</title>
          <link>https://example.com/first</link>
          <guid>guid-1</guid>
        </item>
      </channel></rss>
      """)

      assert {:ok, 1} = Feeds.poll_outlet(outlet)
      assert {:ok, 0} = Feeds.poll_outlet(outlet)
      assert length(Feeds.list_coverage()) == 1
    end

    test "dedupes on url when the feed item has no guid" do
      outlet = create_outlet!()

      stub_feed("""
      <rss version="2.0"><channel>
        <item>
          <title>No guid story</title>
          <link>https://example.com/no-guid</link>
        </item>
      </channel></rss>
      """)

      assert {:ok, 1} = Feeds.poll_outlet(outlet)
      assert {:ok, 0} = Feeds.poll_outlet(outlet)
      assert [coverage] = Feeds.list_coverage()
      assert coverage.dedup_key == "https://example.com/no-guid"
    end

    test "returns an error when the fetch fails" do
      outlet = create_outlet!()

      Req.Test.stub(Fetcher, fn conn ->
        Plug.Conn.send_resp(conn, 500, "boom")
      end)

      assert {:error, {:http_status, 500}} = Feeds.poll_outlet(outlet)
    end
  end

  describe "list_coverage/1" do
    test "defaults to 30 items, respects an explicit limit" do
      outlet = create_outlet!()
      for _ <- 1..35, do: insert_coverage!(outlet, %{})

      assert length(Feeds.list_coverage()) == 30
      assert length(Feeds.list_coverage(limit: 5)) == 5
    end

    test "sorts newest first, falling back to inserted_at when published_at is null" do
      outlet = create_outlet!()

      old = insert_coverage!(outlet, %{published_at: ~U[2024-01-01 00:00:00Z]})

      undated_recent =
        insert_coverage!(outlet, %{
          published_at: nil,
          inserted_at: ~U[2024-06-01 00:00:00Z]
        })

      newest =
        insert_coverage!(outlet, %{published_at: ~U[2024-12-01 00:00:00Z]})

      assert Feeds.list_coverage() |> Enum.map(& &1.id) ==
               [newest.id, undated_recent.id, old.id]
    end
  end

  describe "poll_all_outlets/0" do
    test "one outlet failing doesn't stop the others from being stored" do
      working =
        create_outlet!(%{
          name: "Working",
          feed_url: "https://example.com/ok.xml"
        })

      broken =
        create_outlet!(%{
          name: "Broken",
          feed_url: "https://example.com/broken.xml"
        })

      Req.Test.stub(Fetcher, fn conn ->
        if String.ends_with?(conn.request_path, "broken.xml") do
          Plug.Conn.send_resp(conn, 500, "boom")
        else
          Req.Test.text(conn, """
          <rss version="2.0"><channel>
            <item>
              <title>Story</title>
              <link>https://example.com/story</link>
              <guid>guid-1</guid>
            </item>
          </channel></rss>
          """)
        end
      end)

      results = Feeds.poll_all_outlets()

      assert results[working.id] == {:ok, 1}
      assert results[broken.id] == {:error, {:http_status, 500}}
      assert length(Feeds.list_coverage()) == 1
    end
  end
end
