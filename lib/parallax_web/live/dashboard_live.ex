defmodule ParallaxWeb.DashboardLive do
  use ParallaxWeb, :live_view

  alias Parallax.Feeds

  @page_size 30

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, coverage: Feeds.list_coverage(limit: @page_size))}
  end

  attr :item, Parallax.Feeds.Coverage, required: true

  defp coverage_card(assigns) do
    ~H"""
    <article class="border-b border-zinc-200 py-4">
      <a
        href={@item.url}
        target="_blank"
        rel="noopener noreferrer"
        class="text-lg font-semibold hover:underline"
      >
        {@item.title}
      </a>
      <p class="text-sm text-zinc-500">
        {@item.outlet.name} · {published_label(@item.published_at)}
      </p>
      <p :if={@item.summary} class="mt-1 text-zinc-700">{@item.summary}</p>
    </article>
    """
  end

  defp published_label(nil), do: "undated"

  defp published_label(datetime),
    do: Calendar.strftime(datetime, "%b %d, %Y %H:%M UTC")
end
