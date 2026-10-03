defmodule Parallax.Repo.Migrations.CreateStorySynthesisPerspectives do
  use Ecto.Migration

  def change do
    create table(:story_synthesis_perspectives) do
      add :synthesis_id, references(:story_syntheses, on_delete: :delete_all), null: false
      add :label, :string, null: false
      add :description, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:story_synthesis_perspectives, [:synthesis_id])
  end
end
