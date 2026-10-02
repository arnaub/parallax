defmodule Parallax.Feeds.Coverage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Parallax.Feeds.Outlet

  schema "coverage" do
    field :dedup_key, :string
    field :url, :string
    field :title, :string
    field :summary, :string
    field :published_at, :utc_datetime

    belongs_to :outlet, Outlet

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
end
