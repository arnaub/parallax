defmodule Parallax.Repo.Migrations.CreateStorySyntheses do
  use Ecto.Migration

  def change do
    create table(:story_syntheses) do
      add :story_id, references(:stories, on_delete: :delete_all), null: false
      add :started, :text, null: false
      add :current_state, :text, null: false
      add :implications, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:story_syntheses, [:story_id, :inserted_at])
  end
end
