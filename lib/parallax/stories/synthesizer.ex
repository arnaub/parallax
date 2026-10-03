defmodule Parallax.Stories.Synthesizer do
  @moduledoc """
  Builds an updated synthesis for one Story: the prompt, the Gemini
  call, and turning the structured response into plain maps ready for
  `Stories` to persist. Doesn't touch the database itself — `Stories`
  owns inserting the Synthesis/Perspective/OutletFraming rows, since it
  needs to resolve perspective labels to real ids as it inserts them.

  Outlet attribution is validated here before being handed back: a
  framing is only kept if its `outlet_id` is one of the outlets whose
  Coverage was actually fed into this call.
  """

  alias Parallax.Stories.Gemini

  @response_schema %{
    type: "OBJECT",
    properties: %{
      "started" => %{type: "STRING"},
      "current_state" => %{type: "STRING"},
      "implications" => %{type: "STRING"},
      "perspectives" => %{
        type: "ARRAY",
        items: %{
          type: "OBJECT",
          properties: %{
            "label" => %{type: "STRING"},
            "description" => %{type: "STRING"}
          },
          required: ["label", "description"]
        }
      },
      "outlet_framings" => %{
        type: "ARRAY",
        items: %{
          type: "OBJECT",
          properties: %{
            "outlet_id" => %{type: "INTEGER"},
            "perspective_label" => %{type: "STRING", nullable: true},
            "framing" => %{type: "STRING"}
          },
          required: ["outlet_id", "perspective_label", "framing"]
        }
      }
    },
    required: [
      "started",
      "current_state",
      "implications",
      "perspectives",
      "outlet_framings"
    ]
  }

  @spec synthesize(struct(), struct() | nil, [struct()]) ::
          {:ok, map()} | {:error, term()}
  def synthesize(story, previous_synthesis, coverage_items) do
    known_outlet_ids = coverage_items |> Enum.map(& &1.outlet_id) |> Enum.uniq()
    prompt = build_prompt(story, previous_synthesis, coverage_items)

    case Gemini.generate(prompt, @response_schema) do
      {:ok, decision} -> interpret(decision, known_outlet_ids)
      {:error, reason} -> {:error, reason}
    end
  end

  defp interpret(
         %{
           "started" => started,
           "current_state" => current_state,
           "implications" => implications,
           "perspectives" => perspectives,
           "outlet_framings" => outlet_framings
         },
         known_outlet_ids
       )
       when is_binary(started) and is_binary(current_state) and
              is_binary(implications) and
              is_list(perspectives) and is_list(outlet_framings) do
    {:ok,
     %{
       started: started,
       current_state: current_state,
       implications: implications,
       perspectives: Enum.map(perspectives, &parse_perspective/1),
       outlet_framings: build_outlet_framings(outlet_framings, known_outlet_ids)
     }}
  end

  defp interpret(decision, _known_outlet_ids),
    do: {:error, {:unexpected_decision, decision}}

  defp parse_perspective(%{"label" => label, "description" => description}) do
    %{label: label, description: description}
  end

  defp build_outlet_framings(raw_framings, known_outlet_ids) do
    raw_framings
    |> Enum.map(&parse_framing/1)
    |> Enum.filter(&(&1.outlet_id in known_outlet_ids))
  end

  defp parse_framing(%{"outlet_id" => outlet_id, "framing" => framing} = raw) do
    %{
      outlet_id: outlet_id,
      perspective_label: Map.get(raw, "perspective_label"),
      framing: framing
    }
  end

  defp build_prompt(story, previous_synthesis, coverage_items) do
    """
    You maintain a running synthesis of an ongoing news Story for a
    calm, non-real-time news reader. Produce four things: how the
    situation started, where it stands now, 2-4 named perspectives
    specific to this story (not generic left/right labels), and why it
    matters. Then, for notable outlets, describe how their coverage
    frames the story and which perspective (by its exact label) it
    aligns with — only if it clearly does. Many outlets report
    straight and shouldn't be forced into a perspective; for those,
    leave perspective_label null.

    Stick to what is reported in the coverage below. Do not speculate
    beyond it, especially for why it matters.

    Story: #{story.title}

    #{previous_synthesis_section(previous_synthesis)}

    New coverage since the last update:
    #{format_coverage(coverage_items)}

    Reference outlets only by the outlet_id shown above.
    """
  end

  defp previous_synthesis_section(nil),
    do: "This is the first synthesis for this story."

  defp previous_synthesis_section(synthesis) do
    """
    Previous synthesis (update it, don't start over):
    - Started: #{synthesis.started}
    - Current state: #{synthesis.current_state}
    - Implications: #{synthesis.implications}
    - Perspectives: #{format_perspectives(synthesis.perspectives)}
    """
  end

  defp format_perspectives(perspectives) do
    Enum.map_join(perspectives, "; ", fn p -> "#{p.label}: #{p.description}" end)
  end

  defp format_coverage(coverage_items) do
    Enum.map_join(coverage_items, "\n", fn item ->
      "- outlet_id #{item.outlet_id} (#{item.outlet.name}, #{item.outlet.language}): " <>
        "#{item.title} — #{item.summary}"
    end)
  end
end
