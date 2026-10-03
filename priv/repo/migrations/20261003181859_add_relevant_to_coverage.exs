defmodule Parallax.Repo.Migrations.AddRelevantToCoverage do
  use Ecto.Migration

  def change do
    alter table(:coverage) do
      add :relevant, :boolean
    end

    create index(:coverage, [:relevant])
  end
end
