# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Parallax.Repo.insert!(%Parallax.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Parallax.Feeds

outlets = [
  %{
    name: "BBC News",
    homepage_url: "https://www.bbc.com/news",
    feed_url: "http://feeds.bbci.co.uk/news/world/rss.xml",
    language: "en"
  },
  %{
    name: "The Guardian",
    homepage_url: "https://www.theguardian.com/world",
    feed_url: "https://www.theguardian.com/world/rss",
    language: "en"
  },
  %{
    name: "NPR",
    homepage_url: "https://www.npr.org",
    feed_url: "https://feeds.npr.org/1001/rss.xml",
    language: "en"
  },
  %{
    name: "The New York Times",
    homepage_url: "https://www.nytimes.com",
    feed_url: "https://rss.nytimes.com/services/xml/rss/nyt/World.xml",
    language: "en"
  },
  %{
    name: "El País",
    homepage_url: "https://elpais.com",
    feed_url: "https://elpais.com/rss/elpais/portada.xml",
    language: "es"
  },
  %{
    name: "El Mundo",
    homepage_url: "https://www.elmundo.es",
    feed_url: "https://e00-elmundo.uecdn.es/elmundo/rss/portada.xml",
    language: "es"
  },
  %{
    name: "VilaWeb",
    homepage_url: "https://www.vilaweb.cat",
    feed_url: "https://www.vilaweb.cat/feed/",
    language: "ca"
  },
  %{
    name: "Ara",
    homepage_url: "https://www.ara.cat",
    feed_url: "https://www.ara.cat/rss/",
    language: "ca"
  },
  %{
    name: "NacióDigital",
    homepage_url: "https://www.naciodigital.cat",
    feed_url: "https://www.naciodigital.cat/rss",
    language: "ca"
  }
]

for attrs <- outlets do
  case Feeds.create_outlet(attrs) do
    {:ok, outlet} ->
      IO.puts("seeded outlet: #{outlet.name}")

    {:error, changeset} ->
      IO.inspect(changeset.errors, label: "skipped #{attrs.name}")
  end
end
