defmodule Parallax.Repo.Migrations.CreateCoverage do
  use Ecto.Migration

  def change do
    create table(:coverage) do
      add :outlet_id, references(:outlets, on_delete: :delete_all), null: false
      add :dedup_key, :string, null: false
      add :url, :string, null: false
      add :title, :string, null: false
      add :summary, :text
      add :published_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:coverage, [:outlet_id])
    create unique_index(:coverage, [:outlet_id, :dedup_key])
  end
end
