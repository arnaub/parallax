defmodule Parallax.Repo.Migrations.CreateStories do
  use Ecto.Migration

  def change do
    create table(:stories) do
      add :title, :string, null: false
      add :description, :text, null: false
      add :last_coverage_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:stories, [:last_coverage_at])
  end
end
