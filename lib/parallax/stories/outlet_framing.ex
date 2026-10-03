defmodule Parallax.Stories.OutletFraming do
  use Ecto.Schema
  import Ecto.Changeset

  alias Parallax.Feeds.Outlet
  alias Parallax.Stories.Perspective
  alias Parallax.Stories.Synthesis

  schema "story_synthesis_outlet_framings" do
    field :framing, :string

    belongs_to :synthesis, Synthesis
    belongs_to :outlet, Outlet
    belongs_to :perspective, Perspective

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @required_fields [:synthesis_id, :outlet_id, :framing]
  @optional_fields [:perspective_id]

  def changeset(outlet_framing, attrs) do
    outlet_framing
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
