defmodule Parallax.Feeds.Outlet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "outlets" do
    field :name, :string
    field :homepage_url, :string
    field :feed_url, :string
    field :language, :string

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @required_fields [:name, :homepage_url, :feed_url, :language]

  def changeset(outlet, attrs) do
    outlet
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:feed_url)
  end
end
