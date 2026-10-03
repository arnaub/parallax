defmodule Parallax.Stories.Story do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stories" do
    field :title, :string
    field :description, :string
    field :last_coverage_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @required_fields [:title, :description, :last_coverage_at]

  def changeset(story, attrs) do
    story
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
  end
end
