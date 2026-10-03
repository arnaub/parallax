defmodule Parallax.FeedsTest do
  use Parallax.DataCase, async: true

  alias Parallax.Feeds
  alias Parallax.Feeds.Coverage
  alias Parallax.Feeds.Fetcher
  alias Parallax.Stories.Story

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

  describe "list_unclustered_coverage/0, assign_story/2, and mark_irrelevant/1" do
    test "only returns Coverage never screened, oldest first" do
      outlet = create_outlet!()

      unscreened_old =
        insert_coverage!(outlet, %{published_at: ~U[2024-01-01 00:00:00Z]})

      unscreened_new =
        insert_coverage!(outlet, %{published_at: ~U[2024-02-01 00:00:00Z]})

      clustered =
        insert_coverage!(outlet, %{
          published_at: ~U[2024-03-01 00:00:00Z],
          story_id: insert_story!().id,
          relevant: true
        })

      screened_irrelevant =
        insert_coverage!(outlet, %{
          published_at: ~U[2024-04-01 00:00:00Z],
          relevant: false
        })

      results = Feeds.list_unclustered_coverage()

      assert Enum.map(results, & &1.id) == [
               unscreened_old.id,
               unscreened_new.id
             ]

      refute clustered.id in Enum.map(results, & &1.id)
      refute screened_irrelevant.id in Enum.map(results, & &1.id)
    end

    test "assign_story/2 sets story_id and marks relevant" do
      outlet = create_outlet!()
      coverage = insert_coverage!(outlet, %{})
      story = insert_story!()

      assert {:ok, updated} = Feeds.assign_story(coverage, story.id)
      assert updated.story_id == story.id
      assert updated.relevant == true
    end

    test "mark_irrelevant/1 sets relevant to false without a story_id" do
      outlet = create_outlet!()
      coverage = insert_coverage!(outlet, %{})

      assert {:ok, updated} = Feeds.mark_irrelevant(coverage)
      assert updated.relevant == false
      assert updated.story_id == nil
    end
  end

  describe "list_coverage_by_story/2" do
    test "only returns that Story's Coverage, oldest first" do
      outlet = create_outlet!()
      story = insert_story!()
      other_story = insert_story!()

      older =
        insert_coverage!(outlet, %{
          story_id: story.id,
          inserted_at: ~U[2024-01-01 00:00:00Z]
        })

      newer =
        insert_coverage!(outlet, %{
          story_id: story.id,
          inserted_at: ~U[2024-02-01 00:00:00Z]
        })

      insert_coverage!(outlet, %{story_id: other_story.id})

      results = Feeds.list_coverage_by_story(story.id)

      assert Enum.map(results, & &1.id) == [older.id, newer.id]
    end

    test "with :since, only returns Coverage inserted after that time" do
      outlet = create_outlet!()
      story = insert_story!()

      insert_coverage!(outlet, %{
        story_id: story.id,
        inserted_at: ~U[2024-01-01 00:00:00Z]
      })

      recent =
        insert_coverage!(outlet, %{
          story_id: story.id,
          inserted_at: ~U[2024-03-01 00:00:00Z]
        })

      results =
        Feeds.list_coverage_by_story(story.id, since: ~U[2024-02-01 00:00:00Z])

      assert Enum.map(results, & &1.id) == [recent.id]
    end
  end

  defp insert_story!(attrs \\ %{}) do
    defaults = %{
      title: "A story",
      description: "A description",
      last_coverage_at: ~U[2024-01-01 00:00:00Z]
    }

    %Story{}
    |> Story.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
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
