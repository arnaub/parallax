defmodule Parallax.Stories.SynthesizerTest do
  use ExUnit.Case, async: true

  alias Parallax.Stories.Gemini
  alias Parallax.Stories.Synthesizer

  defp story(attrs \\ %{}) do
    Map.merge(%{id: 1, title: "A story", description: "A description"}, attrs)
  end

  defp coverage_item(attrs) do
    defaults = %{
      title: "Title",
      summary: "Summary",
      outlet_id: 1,
      outlet: %{name: "Example Outlet", language: "en"}
    }

    Map.merge(defaults, attrs)
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

  defp valid_decision(overrides \\ %{}) do
    Map.merge(
      %{
        "started" => "It started with X",
        "current_state" => "Now it's Y",
        "implications" => "This matters because Z",
        "perspectives" => [
          %{"label" => "Government", "description" => "Argues for the decree"}
        ],
        "outlet_framings" => [
          %{
            "outlet_id" => 1,
            "perspective_label" => "Government",
            "framing" => "Supportive"
          }
        ]
      },
      overrides
    )
  end

  test "interprets a valid response into plain maps" do
    stub_gemini_json(valid_decision())

    assert {:ok, result} =
             Synthesizer.synthesize(story(), nil, [
               coverage_item(%{outlet_id: 1})
             ])

    assert result.started == "It started with X"
    assert result.current_state == "Now it's Y"
    assert result.implications == "This matters because Z"

    assert result.perspectives == [
             %{label: "Government", description: "Argues for the decree"}
           ]

    assert result.outlet_framings == [
             %{
               outlet_id: 1,
               perspective_label: "Government",
               framing: "Supportive"
             }
           ]
  end

  test "drops a framing whose outlet_id wasn't among the candidates fed into the call" do
    stub_gemini_json(
      valid_decision(%{
        "outlet_framings" => [
          %{
            "outlet_id" => 1,
            "perspective_label" => nil,
            "framing" => "Known outlet"
          },
          %{
            "outlet_id" => 99,
            "perspective_label" => nil,
            "framing" => "Hallucinated outlet"
          }
        ]
      })
    )

    assert {:ok, result} =
             Synthesizer.synthesize(story(), nil, [
               coverage_item(%{outlet_id: 1})
             ])

    assert [%{outlet_id: 1, framing: "Known outlet"}] = result.outlet_framings
  end

  test "keeps perspective_label nil when the outlet doesn't clearly align" do
    stub_gemini_json(
      valid_decision(%{
        "outlet_framings" => [
          %{
            "outlet_id" => 1,
            "perspective_label" => nil,
            "framing" => "Straight reporting"
          }
        ]
      })
    )

    assert {:ok, result} =
             Synthesizer.synthesize(story(), nil, [
               coverage_item(%{outlet_id: 1})
             ])

    assert [%{perspective_label: nil}] = result.outlet_framings
  end

  test "returns an error for an unparseable decision" do
    stub_gemini_json(%{"unexpected" => "shape"})

    assert {:error, {:unexpected_decision, _decision}} =
             Synthesizer.synthesize(story(), nil, [coverage_item(%{})])
  end

  test "returns an error when Gemini itself fails" do
    Req.Test.stub(Gemini, fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

    assert {:error, {:http_status, 500, "boom"}} =
             Synthesizer.synthesize(story(), nil, [coverage_item(%{})])
  end
end
