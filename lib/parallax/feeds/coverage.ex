defmodule Parallax.Feeds.Coverage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Parallax.Feeds.Outlet
  alias Parallax.Stories.Story

  schema "coverage" do
    field :dedup_key, :string
    field :url, :string
    field :title, :string
    field :summary, :string
    field :published_at, :utc_datetime
    field :relevant, :boolean

    belongs_to :outlet, Outlet
    belongs_to :story, Story

    timestamps(type: :utc_datetime)
  end

  @required_fields [:outlet_id, :dedup_key, :url, :title]
  @optional_fields [:summary, :published_at]

  def changeset(coverage, attrs) do
    coverage
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:outlet_id, :dedup_key])
  end

  @doc "Assigns which Story this Coverage belongs to, marking it relevant."
  def story_changeset(coverage, story_id) do
    attrs = %{story_id: story_id, relevant: true}
    cast(coverage, attrs, [:story_id, :relevant])
  end

  @doc "Marks this Coverage as screened and not significant enough for a Story."
  def irrelevant_changeset(coverage) do
    cast(coverage, %{relevant: false}, [:relevant])
  end
end
