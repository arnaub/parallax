defmodule Parallax.Repo.Migrations.CreateStorySynthesisOutletFramings do
  use Ecto.Migration

  def change do
    create table(:story_synthesis_outlet_framings) do
      add :synthesis_id, references(:story_syntheses, on_delete: :delete_all), null: false
      add :outlet_id, references(:outlets, on_delete: :delete_all), null: false

      add :perspective_id,
          references(:story_synthesis_perspectives, on_delete: :nilify_all)

      add :framing, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:story_synthesis_outlet_framings, [:synthesis_id])
    create index(:story_synthesis_outlet_framings, [:outlet_id])
    create index(:story_synthesis_outlet_framings, [:perspective_id])
  end
end
