defmodule Parallax.Stories.Gemini do
  @moduledoc """
  The only module that knows about the Gemini HTTP API. Takes a prompt
  and a response schema, returns the model's structured JSON response.

  Uses `gemini-3.8-flash` via the standard `generateContent` REST
  endpoint. `gemini-2.5-flash` (the original choice — see ADR 0002) was
  found live, via a real 404 from the API itself, to no longer be
  available to new API keys; Google now says free-tier limits aren't
  published and vary per project, visible only on each account's own
  AI Studio rate-limits page.

  On a 429 (rate limited) or 503 (temporarily overloaded — confirmed a
  real, non-rare occurrence in live testing against gemini-3.8-flash),
  retries a couple of times. Honors the API's own `retryDelay` when
  present (429 only; 503 has none, so uses the default delay). This is
  a safety net on top of `Stories`' own pacing between calls, not the
  primary defense against the rate limit.
  """

  @model "gemini-3.8-flash"
  @endpoint "https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent"
  @max_retries 2

  @spec generate(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def generate(prompt, response_schema) do
    with {:ok, api_key} <- fetch_api_key() do
      request(prompt, response_schema, api_key, @max_retries)
    end
  end

  defp fetch_api_key do
    case System.get_env("GEMINI_API_KEY") do
      key when key in [nil, ""] -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  end

  defp request(prompt, response_schema, api_key, retries_left) do
    options =
      [
        url: @endpoint,
        params: [key: api_key],
        json: request_body(prompt, response_schema),
        retry: false
      ] ++ req_options()

    case options |> Req.new() |> Req.post() |> handle_response() do
      {:error, {reason, delay_ms}}
      when reason in [:rate_limited, :unavailable] and retries_left > 0 ->
        Process.sleep(delay_ms)
        request(prompt, response_schema, api_key, retries_left - 1)

      result ->
        result
    end
  end

  defp request_body(prompt, response_schema) do
    %{
      contents: [%{parts: [%{text: prompt}]}],
      generationConfig: %{
        response_mime_type: "application/json",
        response_schema: response_schema
      }
    }
  end

  # Lets tests swap in a Req.Test plug via config instead of hitting the
  # network; left empty in :dev/:prod so requests go out for real.
  defp req_options, do: Application.get_env(:parallax, :stories_req_options, [])

  defp handle_response({:ok, %{status: 200, body: body}}), do: parse_text(body)

  defp handle_response({:ok, %{status: 429, body: body}}),
    do: {:error, {:rate_limited, retry_delay_ms(body)}}

  defp handle_response({:ok, %{status: 503}}),
    do: {:error, {:unavailable, default_retry_delay_ms()}}

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, {:http_status, status, body}}

  defp handle_response({:error, reason}), do: {:error, reason}

  defp retry_delay_ms(body) do
    case find_retry_delay_seconds(body) do
      {:ok, seconds} -> round(seconds * 1000)
      :error -> default_retry_delay_ms()
    end
  end

  defp default_retry_delay_ms do
    Application.get_env(
      :parallax,
      :stories_default_retry_delay_ms,
      :timer.seconds(15)
    )
  end

  defp find_retry_delay_seconds(%{"error" => %{"details" => details}})
       when is_list(details) do
    details
    |> Enum.find_value(&parse_retry_delay/1)
    |> case do
      nil -> :error
      seconds -> {:ok, seconds}
    end
  end

  defp find_retry_delay_seconds(_body), do: :error

  defp parse_retry_delay(%{"retryDelay" => delay}) when is_binary(delay) do
    case Float.parse(String.trim_trailing(delay, "s")) do
      {seconds, _rest} -> seconds
      :error -> nil
    end
  end

  defp parse_retry_delay(_detail), do: nil

  defp parse_text(%{
         "candidates" => [
           %{"content" => %{"parts" => [%{"text" => text} | _]}} | _
         ]
       }) do
    case Jason.decode(text) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, {:invalid_json, reason}}
    end
  end

  defp parse_text(body), do: {:error, {:unexpected_response, body}}
end
