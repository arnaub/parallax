defmodule Parallax.Stories.Perspective do
  use Ecto.Schema
  import Ecto.Changeset

  alias Parallax.Stories.Synthesis

  schema "story_synthesis_perspectives" do
    field :label, :string
    field :description, :string

    belongs_to :synthesis, Synthesis

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @required_fields [:synthesis_id, :label, :description]

  def changeset(perspective, attrs) do
    perspective
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
  end
end
