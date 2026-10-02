defmodule Parallax.Feeds.Fetcher do
  @moduledoc """
  Fetches a feed URL and parses its items into plain maps. The only
  module in `Feeds` that knows about HTTP or feed XML.
  """

  import SweetXml

  @type item :: %{
          guid: String.t() | nil,
          url: String.t(),
          title: String.t(),
          summary: String.t() | nil,
          published_at: DateTime.t() | nil
        }

  @user_agent "Parallax/1.0 (+https://github.com/arnaub/parallax)"

  @spec fetch(String.t()) :: {:ok, [item]} | {:error, term()}
  def fetch(feed_url) do
    options =
      [url: feed_url, headers: [{"user-agent", @user_agent}], retry: false] ++
        req_options()

    request = Req.new(options)

    case Req.get(request) do
      {:ok, %{status: 200, body: body}} -> parse_feed(body)
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  # Lets tests swap in a Req.Test plug via config instead of hitting the
  # network; left empty in :dev/:prod so requests go out for real.
  defp req_options, do: Application.get_env(:parallax, :feeds_req_options, [])

  defp parse_feed(xml) do
    doc = SweetXml.parse(xml, quiet: true)

    entries =
      case xpath(doc, ~x"//item"l) do
        [] -> atom_entries(doc)
        _items -> rss_items(doc)
      end

    {:ok, entries}
  rescue
    error -> {:error, {:parse_error, error}}
  catch
    :exit, reason -> {:error, {:parse_error, reason}}
  end

  defp rss_items(doc) do
    doc
    |> xpath(
      ~x"//item"l,
      guid: ~x"./guid/text()"so,
      url: ~x"./link/text()"so,
      title: ~x"./title/text()"so,
      summary: ~x"./description/text()"so,
      published_at: ~x"./pubDate/text()"so
    )
    |> Enum.map(&normalize/1)
  end

  defp atom_entries(doc) do
    doc
    |> xpath(
      ~x"//entry"l,
      guid: ~x"./id/text()"so,
      url: ~x"./link/@href"so,
      title: ~x"./title/text()"so,
      summary: ~x"./summary/text()"so,
      published: ~x"./published/text()"so,
      updated: ~x"./updated/text()"so
    )
    |> Enum.map(fn entry ->
      entry
      |> Map.put(:published_at, entry[:published] || entry[:updated])
      |> Map.drop([:published, :updated])
    end)
    |> Enum.map(&normalize/1)
  end

  defp normalize(entry) do
    %{
      guid: blank_to_nil(entry.guid),
      url: String.trim(entry.url || ""),
      title: String.trim(entry.title || ""),
      summary: blank_to_nil(entry.summary),
      published_at: parse_datetime(entry.published_at)
    }
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(string) do
    case String.trim(string) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> parse_rfc822(string)
    end
  end

  # RFC 822 pubDate strings name a timezone, but we treat the clock time
  # as UTC regardless of which zone is named — close enough for sorting
  # and display, and avoids writing our own timezone-name parser.
  defp parse_rfc822(string) do
    case :httpd_util.convert_request_date(String.to_charlist(string)) do
      {date, time} ->
        {date, time}
        |> NaiveDateTime.from_erl!()
        |> DateTime.from_naive!("Etc/UTC")

      :bad_date ->
        nil
    end
  rescue
    _error -> nil
  end
end
