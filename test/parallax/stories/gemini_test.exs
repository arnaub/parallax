defmodule Parallax.Stories.GeminiTest do
  use ExUnit.Case, async: true

  alias Parallax.Stories.Gemini

  @schema %{
    type: "OBJECT",
    properties: %{"answer" => %{type: "STRING"}},
    required: ["answer"]
  }

  defp stub_gemini_text(json_text) do
    Req.Test.stub(Gemini, fn conn ->
      body = %{
        "candidates" => [%{"content" => %{"parts" => [%{"text" => json_text}]}}]
      }

      Req.Test.json(conn, body)
    end)
  end

  test "decodes the model's JSON text response" do
    stub_gemini_text(Jason.encode!(%{"answer" => "42"}))

    assert {:ok, %{"answer" => "42"}} = Gemini.generate("a prompt", @schema)
  end

  test "returns an error when the API key is missing" do
    System.delete_env("GEMINI_API_KEY")
    on_exit(fn -> System.put_env("GEMINI_API_KEY", "test-key") end)

    assert {:error, :missing_api_key} = Gemini.generate("a prompt", @schema)
  end

  test "returns an error for a non-200 response" do
    Req.Test.stub(Gemini, fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

    assert {:error, {:http_status, 500, "boom"}} =
             Gemini.generate("a prompt", @schema)
  end

  test "returns an error when the model's text isn't valid JSON" do
    stub_gemini_text("not json")

    assert {:error, {:invalid_json, _reason}} =
             Gemini.generate("a prompt", @schema)
  end

  test "returns an error for an unexpected response shape" do
    Req.Test.stub(Gemini, fn conn ->
      Req.Test.json(conn, %{"unexpected" => true})
    end)

    assert {:error, {:unexpected_response, _body}} =
             Gemini.generate("a prompt", @schema)
  end

  defp rate_limited_response(retry_delay) do
    details =
      if retry_delay do
        [%{"retryDelay" => retry_delay}]
      else
        []
      end

    %{"error" => %{"code" => 429, "details" => details}}
  end

  test "retries on 429 honoring retryDelay, then succeeds" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Req.Test.stub(Gemini, fn conn ->
      attempt = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

      if attempt == 0 do
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(rate_limited_response("0.01s"))
      else
        body = %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(%{"answer" => "42"})}]
              }
            }
          ]
        }

        Req.Test.json(conn, body)
      end
    end)

    assert {:ok, %{"answer" => "42"}} = Gemini.generate("a prompt", @schema)
  end

  test "gives up after exhausting retries" do
    Req.Test.stub(Gemini, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(rate_limited_response("0.01s"))
    end)

    assert {:error, {:rate_limited, _delay_ms}} =
             Gemini.generate("a prompt", @schema)
  end

  test "falls back to a default delay when retryDelay is absent" do
    Req.Test.stub(Gemini, fn conn ->
      conn
      |> Plug.Conn.put_status(429)
      |> Req.Test.json(rate_limited_response(nil))
    end)

    assert {:error, {:rate_limited, _delay_ms}} =
             Gemini.generate("a prompt", @schema)
  end

  test "retries on 503 (overloaded), then succeeds" do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Req.Test.stub(Gemini, fn conn ->
      attempt = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

      if attempt == 0 do
        Plug.Conn.send_resp(conn, 503, "overloaded")
      else
        body = %{
          "candidates" => [
            %{
              "content" => %{
                "parts" => [%{"text" => Jason.encode!(%{"answer" => "42"})}]
              }
            }
          ]
        }

        Req.Test.json(conn, body)
      end
    end)

    assert {:ok, %{"answer" => "42"}} = Gemini.generate("a prompt", @schema)
  end

  test "gives up on 503 after exhausting retries" do
    Req.Test.stub(Gemini, fn conn ->
      Plug.Conn.send_resp(conn, 503, "overloaded")
    end)

    assert {:error, {:unavailable, _delay_ms}} =
             Gemini.generate("a prompt", @schema)
  end
end
