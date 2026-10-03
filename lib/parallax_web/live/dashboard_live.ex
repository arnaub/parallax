defmodule ParallaxWeb.DashboardLive do
  use ParallaxWeb, :live_view

  alias Parallax.Stories

  @page_size 30

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, stories: Stories.list_stories(limit: @page_size))}
  end

  attr :story, Parallax.Stories.Story, required: true

  defp story_card(assigns) do
    ~H"""
    <article class="border-b border-zinc-200 py-4">
      <.link
        navigate={~p"/stories/#{@story.id}"}
        class="text-lg font-semibold hover:underline"
      >
        {@story.title}
      </.link>
      <p class="mt-1 text-zinc-700">{@story.description}</p>
    </article>
    """
  end
end
