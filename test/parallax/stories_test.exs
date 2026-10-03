defmodule Parallax.StoriesTest do
  use Parallax.DataCase, async: true

  alias Parallax.Feeds
  alias Parallax.Stories
  alias Parallax.Stories.Gemini
  alias Parallax.Stories.Story
  alias Parallax.Stories.Synthesis

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
      url: "https://example.com/#{System.unique_integer([:positive])}",
      title: "A story",
      summary: "A summary",
      inserted_at: ~U[2024-01-01 00:00:00Z],
      updated_at: ~U[2024-01-01 00:00:00Z]
    }

    Parallax.Feeds.Coverage
    |> struct(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_story!(attrs) do
    defaults = %{
      title: "A story",
      description: "A description",
      last_coverage_at: ~U[2024-01-01 00:00:00Z]
    }

    %Story{}
    |> Story.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp stub_gemini_decision(decision) do
    Req.Test.stub(Gemini, fn conn ->
      body = %{
        "candidates" => [
          %{"content" => %{"parts" => [%{"text" => Jason.encode!(decision)}]}}
        ]
      }

      Req.Test.json(conn, body)
    end)
  end

  describe "list_stories/1" do
    test "newest-active first, optionally limited" do
      old = insert_story!(%{last_coverage_at: ~U[2024-01-01 00:00:00Z]})
      new = insert_story!(%{last_coverage_at: ~U[2024-06-01 00:00:00Z]})

      assert Stories.list_stories() |> Enum.map(& &1.id) == [new.id, old.id]
      assert length(Stories.list_stories(limit: 1)) == 1
    end
  end

  describe "cluster_unclustered_coverage/0" do
    test "attaches a matched item to the existing Story and bumps last_coverage_at" do
      outlet = create_outlet!()
      story = insert_story!(%{last_coverage_at: ~U[2024-01-01 00:00:00Z]})

      insert_coverage!(outlet, %{published_at: ~U[2024-06-01 00:00:00Z]})

      stub_gemini_decision(%{
        "relevant" => true,
        "match_story_id" => story.id,
        "title" => "",
        "description" => ""
      })

      assert [{:ok, :matched}] = Stories.cluster_unclustered_coverage()

      assert Feeds.list_unclustered_coverage() == []
      reloaded_story = Repo.get!(Story, story.id)
      assert reloaded_story.last_coverage_at == ~U[2024-06-01 00:00:00Z]
    end

    test "creates a new Story when there's no match" do
      outlet = create_outlet!()
      insert_coverage!(outlet, %{})

      stub_gemini_decision(%{
        "relevant" => true,
        "match_story_id" => nil,
        "title" => "New situation",
        "description" => "What's happening"
      })

      assert [{:ok, :new_story}] = Stories.cluster_unclustered_coverage()

      assert [story] = Stories.list_stories()
      assert story.title == "New situation"
      assert Feeds.list_unclustered_coverage() == []
    end

    test "marks an irrelevant item without creating or attaching a Story" do
      outlet = create_outlet!()
      insert_coverage!(outlet, %{})

      stub_gemini_decision(%{
        "relevant" => false,
        "match_story_id" => nil,
        "title" => "",
        "description" => ""
      })

      assert [{:ok, :irrelevant}] = Stories.cluster_unclustered_coverage()

      assert Stories.list_stories() == []
      assert Feeds.list_unclustered_coverage() == []
    end

    test "one item's Gemini failure doesn't stop the others from being clustered" do
      outlet = create_outlet!()
      broken = insert_coverage!(outlet, %{title: "broken"})
      working = insert_coverage!(outlet, %{title: "working"})

      Req.Test.stub(Gemini, fn conn ->
        {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(raw_body)

        text =
          get_in(body, ["contents", Access.at(0), "parts", Access.at(0), "text"]) ||
            ""

        if String.contains?(text, "broken") do
          Plug.Conn.send_resp(conn, 500, "boom")
        else
          Req.Test.json(conn, %{
            "candidates" => [
              %{
                "content" => %{
                  "parts" => [
                    %{
                      "text" =>
                        Jason.encode!(%{
                          "relevant" => true,
                          "match_story_id" => nil,
                          "title" => "Working story",
                          "description" => "desc"
                        })
                    }
                  ]
                }
              }
            ]
          })
        end
      end)

      results = Stories.cluster_unclustered_coverage()

      assert Enum.any?(results, &match?({:error, _reason}, &1))
      assert Enum.any?(results, &match?({:ok, :new_story}, &1))

      still_unclustered = Feeds.list_unclustered_coverage()
      assert Enum.map(still_unclustered, & &1.id) == [broken.id]
      assert working.id not in Enum.map(still_unclustered, & &1.id)
    end
  end

  describe "get_story!/1 and latest_synthesis/1" do
    test "get_story!/1 fetches a Story by id" do
      story = insert_story!(%{})
      assert Stories.get_story!(story.id).id == story.id
    end

    test "latest_synthesis/1 returns nil when none exists" do
      story = insert_story!(%{})
      assert Stories.latest_synthesis(story.id) == nil
    end
  end

  describe "synthesize_stories_with_new_coverage/0" do
    defp synthesis_decision(overrides \\ %{}) do
      Map.merge(
        %{
          "started" => "It started",
          "current_state" => "Now",
          "implications" => "Matters",
          "perspectives" => [
            %{"label" => "Side A", "description" => "Argues X"}
          ],
          "outlet_framings" => []
        },
        overrides
      )
    end

    test "skips a Story with no linked Coverage, without calling Gemini" do
      story = insert_story!(%{last_coverage_at: ~U[2024-06-01 00:00:00Z]})

      Req.Test.stub(Gemini, fn _conn ->
        flunk("Gemini should not have been called")
      end)

      assert [{:ok, :no_coverage}] =
               Stories.synthesize_stories_with_new_coverage()

      assert Stories.latest_synthesis(story.id) == nil
    end

    test "builds a synthesis for a Story with Coverage and no previous version" do
      outlet = create_outlet!()
      story = insert_story!(%{last_coverage_at: ~U[2024-06-01 00:00:00Z]})
      coverage = insert_coverage!(outlet, %{story_id: story.id, relevant: true})

      stub_gemini_decision(
        synthesis_decision(%{
          "outlet_framings" => [
            %{
              "outlet_id" => outlet.id,
              "perspective_label" => "Side A",
              "framing" => "Leans X"
            }
          ]
        })
      )

      assert [{:ok, :synthesized}] =
               Stories.synthesize_stories_with_new_coverage()

      synthesis = Stories.latest_synthesis(story.id)
      assert synthesis.started == "It started"
      assert [%{label: "Side A"}] = synthesis.perspectives
      assert [framing] = synthesis.outlet_framings
      assert framing.outlet_id == coverage.outlet_id
      assert framing.perspective_id == hd(synthesis.perspectives).id
    end

    test "skips a Story with no Coverage newer than its last synthesis" do
      story = insert_story!(%{last_coverage_at: ~U[2024-01-01 00:00:00Z]})

      Synthesis
      |> struct(%{
        story_id: story.id,
        started: "It started",
        current_state: "Now",
        implications: "Matters",
        inserted_at: ~U[2024-02-01 00:00:00Z],
        updated_at: ~U[2024-02-01 00:00:00Z]
      })
      |> Repo.insert!()

      stub_gemini_decision(synthesis_decision())
      assert [] = Stories.synthesize_stories_with_new_coverage()

      assert Stories.latest_synthesis(story.id).current_state == "Now"
    end

    test "one Story's Gemini failure doesn't stop the others" do
      outlet = create_outlet!()

      broken =
        insert_story!(%{
          title: "broken",
          last_coverage_at: ~U[2024-06-01 00:00:00Z]
        })

      insert_coverage!(outlet, %{story_id: broken.id, relevant: true})

      working =
        insert_story!(%{
          title: "working",
          last_coverage_at: ~U[2024-06-01 00:00:00Z]
        })

      insert_coverage!(outlet, %{story_id: working.id, relevant: true})

      Req.Test.stub(Gemini, fn conn ->
        {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(raw_body)

        text =
          get_in(body, ["contents", Access.at(0), "parts", Access.at(0), "text"]) ||
            ""

        if String.contains?(text, "broken") do
          Plug.Conn.send_resp(conn, 500, "boom")
        else
          Req.Test.json(conn, %{
            "candidates" => [
              %{
                "content" => %{
                  "parts" => [%{"text" => Jason.encode!(synthesis_decision())}]
                }
              }
            ]
          })
        end
      end)

      results = Stories.synthesize_stories_with_new_coverage()

      assert Enum.any?(results, &match?({:error, _reason}, &1))
      assert Enum.any?(results, &match?({:ok, :synthesized}, &1))

      assert Stories.latest_synthesis(broken.id) == nil
      assert Stories.latest_synthesis(working.id) != nil
    end
  end
end
