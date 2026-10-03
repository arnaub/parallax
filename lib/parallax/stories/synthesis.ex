defmodule Parallax.Stories.Synthesis do
  use Ecto.Schema
  import Ecto.Changeset

  alias Parallax.Stories.OutletFraming
  alias Parallax.Stories.Perspective
  alias Parallax.Stories.Story

  schema "story_syntheses" do
    field :started, :string
    field :current_state, :string
    field :implications, :string

    belongs_to :story, Story
    has_many :perspectives, Perspective
    has_many :outlet_framings, OutletFraming

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @required_fields [:story_id, :started, :current_state, :implications]

  def changeset(synthesis, attrs) do
    synthesis
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
  end
end
