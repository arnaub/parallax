defmodule Parallax.Stories.Matcher do
  @moduledoc """
  Decides whether one Coverage item is significant news at all, and if
  so, whether it matches an existing Story or starts a new one — all by
  asking Gemini once. The same call always asks for a title/description
  too, used only if relevant and no match is found, so one Coverage
  item costs exactly one Gemini call no matter the outcome.
  """

  alias Parallax.Stories.Gemini

  @response_schema %{
    type: "OBJECT",
    properties: %{
      "relevant" => %{type: "BOOLEAN"},
      "match_story_id" => %{type: "INTEGER", nullable: true},
      "title" => %{type: "STRING"},
      "description" => %{type: "STRING"}
    },
    required: ["relevant", "match_story_id", "title", "description"]
  }

  @spec match(struct(), [struct()]) ::
          :irrelevant
          | {:match, integer()}
          | {:new, String.t(), String.t()}
          | {:error, term()}
  def match(coverage, candidate_stories) do
    prompt = build_prompt(coverage, candidate_stories)

    case Gemini.generate(prompt, @response_schema) do
      {:ok, decision} -> interpret(decision)
      {:error, reason} -> {:error, reason}
    end
  end

  defp interpret(%{"relevant" => false}), do: :irrelevant

  defp interpret(%{"relevant" => true, "match_story_id" => id})
       when is_integer(id),
       do: {:match, id}

  defp interpret(%{
         "relevant" => true,
         "title" => title,
         "description" => description
       })
       when is_binary(title) and byte_size(title) > 0 do
    {:new, title, description}
  end

  defp interpret(decision), do: {:error, {:unexpected_decision, decision}}

  defp build_prompt(coverage, candidate_stories) do
    """
    You are screening and grouping news coverage for a calm, non-real-time
    news reader. Two judgments, in order:

    1. Is this significant news? In scope: politics and government,
    conflict and security, economy and business, and major social issues
    (e.g. housing, immigration, large protests) — from anywhere in the
    world, as long as the event itself is significant. Out of scope:
    lifestyle, culture and entertainment coverage (concerts, bullfighting,
    celebrity news), sports, and routine local interest pieces. If it's
    out of scope, set relevant to false and leave the other fields empty.

    2. If relevant, is this part of an ongoing real-world situation (e.g.
    an armed conflict, a political crisis) that can receive coverage from
    different outlets, in different languages, over weeks or months — not
    a single day's news event. Group it into a Story.

    New coverage to classify:
    - Outlet: #{coverage.outlet.name} (language: #{coverage.outlet.language})
    - Title: #{coverage.title}
    - Summary: #{coverage.summary}

    Candidate existing Stories (pick one if this coverage is clearly
    about the same ongoing situation, even if reported in a different
    language):
    #{format_candidates(candidate_stories)}

    If relevant and it matches one of the candidates, set match_story_id
    to its id and leave title/description as empty strings. If relevant
    but it doesn't match any of them, set match_story_id to null and
    provide a short neutral title and a one-sentence description for the
    new Story it starts.
    """
  end

  defp format_candidates([]), do: "(none yet)"

  defp format_candidates(stories) do
    Enum.map_join(stories, "\n", fn story ->
      "- id #{story.id}: #{story.title} — #{story.description}"
    end)
  end
end
