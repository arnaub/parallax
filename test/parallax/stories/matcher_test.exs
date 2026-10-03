defmodule Parallax.Stories.MatcherTest do
  use ExUnit.Case, async: true

  alias Parallax.Stories.Gemini
  alias Parallax.Stories.Matcher

  defp coverage(attrs \\ %{}) do
    defaults = %{
      title: "Coverage title",
      summary: "Coverage summary",
      outlet: %{name: "Example Outlet", language: "en"}
    }

    Map.merge(defaults, attrs)
  end

  defp candidate_story(attrs) do
    defaults = %{id: 1, title: "Existing story", description: "A description"}
    struct(Parallax.Stories.Story, Map.merge(defaults, attrs))
  end

  defp stub_gemini_json(decision) do
    Req.Test.stub(Gemini, fn conn ->
      body = %{
        "candidates" => [
          %{"content" => %{"parts" => [%{"text" => Jason.encode!(decision)}]}}
        ]
      }

      Req.Test.json(conn, body)
    end)
  end

  test "interprets an irrelevant decision" do
    stub_gemini_json(%{
      "relevant" => false,
      "match_story_id" => nil,
      "title" => "",
      "description" => ""
    })

    assert :irrelevant = Matcher.match(coverage(), [])
  end

  test "interprets a match decision" do
    stub_gemini_json(%{
      "relevant" => true,
      "match_story_id" => 7,
      "title" => "",
      "description" => ""
    })

    assert {:match, 7} = Matcher.match(coverage(), [candidate_story(%{id: 7})])
  end

  test "interprets a new-story decision" do
    stub_gemini_json(%{
      "relevant" => true,
      "match_story_id" => nil,
      "title" => "New situation",
      "description" => "What's happening"
    })

    assert {:new, "New situation", "What's happening"} =
             Matcher.match(coverage(), [])
  end

  test "returns an error for an unparseable decision" do
    stub_gemini_json(%{"unexpected" => "shape"})

    assert {:error, {:unexpected_decision, _decision}} =
             Matcher.match(coverage(), [])
  end

  test "returns an error when Gemini itself fails" do
    Req.Test.stub(Gemini, fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

    assert {:error, {:http_status, 500, "boom"}} = Matcher.match(coverage(), [])
  end
end
