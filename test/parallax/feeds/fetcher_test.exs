defmodule Parallax.Feeds.FetcherTest do
  use ExUnit.Case, async: true

  alias Parallax.Feeds.Fetcher

  @rss """
  <?xml version="1.0" encoding="UTF-8"?>
  <rss version="2.0">
    <channel>
      <title>Example News</title>
      <item>
        <title>First story</title>
        <link>https://example.com/first</link>
        <guid>urn:uuid:1234</guid>
        <pubDate>Wed, 02 Oct 2024 10:00:00 GMT</pubDate>
        <description>Summary of the first story.</description>
      </item>
      <item>
        <title>Second story</title>
        <link>https://example.com/second</link>
        <pubDate>Wed, 02 Oct 2024 11:30:00 +0000</pubDate>
        <description><![CDATA[Has <b>HTML</b> in it]]></description>
      </item>
    </channel>
  </rss>
  """

  @atom """
  <?xml version="1.0" encoding="UTF-8"?>
  <feed xmlns="http://www.w3.org/2005/Atom">
    <title>Example Atom Feed</title>
    <entry>
      <title>Atom story</title>
      <link href="https://example.com/atom-story" rel="alternate"/>
      <id>tag:example.com,2024:atom-story</id>
      <published>2024-10-02T12:00:00Z</published>
      <summary>Atom summary</summary>
    </entry>
  </feed>
  """

  test "parses RSS items, including one with no guid and CDATA content" do
    Req.Test.stub(Fetcher, fn conn -> Req.Test.text(conn, @rss) end)

    assert {:ok, items} = Fetcher.fetch("https://example.com/feed.xml")
    assert length(items) == 2

    [first, second] = items
    assert first.guid == "urn:uuid:1234"
    assert first.url == "https://example.com/first"
    assert first.title == "First story"
    assert first.published_at == ~U[2024-10-02 10:00:00Z]

    assert second.guid == nil
    assert second.summary == "Has HTML in it"
  end

  test "strips embedded HTML and decodes common entities from the summary" do
    xml = """
    <rss version="2.0"><channel>
      <item>
        <title>Story</title>
        <link>https://example.com/story</link>
        <description><![CDATA[Rain & wind today&nbsp;<a href="x">Leer</a><img src="y" alt=""/>]]></description>
      </item>
    </channel></rss>
    """

    Req.Test.stub(Fetcher, fn conn -> Req.Test.text(conn, xml) end)

    assert {:ok, [item]} = Fetcher.fetch("https://example.com/feed.xml")
    assert item.summary == "Rain & wind today Leer"
  end

  test "parses Atom entries" do
    Req.Test.stub(Fetcher, fn conn -> Req.Test.text(conn, @atom) end)

    assert {:ok, [entry]} = Fetcher.fetch("https://example.com/feed.atom")
    assert entry.guid == "tag:example.com,2024:atom-story"
    assert entry.url == "https://example.com/atom-story"
    assert entry.title == "Atom story"
    assert entry.summary == "Atom summary"
    assert entry.published_at == ~U[2024-10-02 12:00:00Z]
  end

  test "returns an error for a non-200 response" do
    Req.Test.stub(Fetcher, fn conn -> Plug.Conn.send_resp(conn, 500, "boom") end)

    assert {:error, {:http_status, 500}} =
             Fetcher.fetch("https://example.com/feed.xml")
  end

  test "returns an error for unparseable content" do
    Req.Test.stub(Fetcher, fn conn ->
      Req.Test.text(conn, "not xml at all <<<")
    end)

    assert {:error, {:parse_error, _reason}} =
             Fetcher.fetch("https://example.com/feed.xml")
  end
end
