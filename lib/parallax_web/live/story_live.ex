defmodule ParallaxWeb.StoryLive do
  use ParallaxWeb, :live_view

  alias Parallax.Stories

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    story = Stories.get_story!(id)
    synthesis = Stories.latest_synthesis(story.id)

    socket =
      assign(socket,
        story: story,
        synthesis: synthesis,
        framing_groups: framing_groups(synthesis)
      )

    {:ok, socket}
  end

  defp framing_groups(nil), do: []

  defp framing_groups(synthesis) do
    by_perspective_id =
      Enum.group_by(synthesis.outlet_framings, & &1.perspective_id)

    named_groups =
      Enum.map(synthesis.perspectives, fn perspective ->
        %{
          label: perspective.label,
          framings: Map.get(by_perspective_id, perspective.id, [])
        }
      end)

    case Map.get(by_perspective_id, nil, []) do
      [] -> named_groups
      unaligned -> named_groups ++ [%{label: nil, framings: unaligned}]
    end
  end

  attr :group, :map, required: true

  defp framing_group(assigns) do
    ~H"""
    <div class="mt-3">
      <h3 class="text-sm font-semibold text-zinc-600">
        {@group.label || "Other coverage"}
      </h3>
      <ul class="mt-1 space-y-1">
        <li :for={framing <- @group.framings} class="text-zinc-700">
          <span class="font-medium">{framing.outlet.name}:</span> {framing.framing}
        </li>
      </ul>
    </div>
    """
  end
end
