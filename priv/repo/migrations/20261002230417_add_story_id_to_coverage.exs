defmodule Parallax.Repo.Migrations.AddStoryIdToCoverage do
  use Ecto.Migration

  def change do
    alter table(:coverage) do
      add :story_id, references(:stories, on_delete: :nilify_all)
    end

    create index(:coverage, [:story_id])
  end
end
