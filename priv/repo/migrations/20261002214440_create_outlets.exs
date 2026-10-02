defmodule Parallax.Repo.Migrations.CreateOutlets do
  use Ecto.Migration

  def change do
    create table(:outlets) do
      add :name, :string, null: false
      add :homepage_url, :string, null: false
      add :feed_url, :string, null: false
      add :language, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:outlets, [:feed_url])
  end
end
