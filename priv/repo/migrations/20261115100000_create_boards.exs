defmodule Easel.Repo.Migrations.CreateBoards do
  use Ecto.Migration

  def change do
    create table(:boards) do
      add :title, :string, null: false
      add :slug, :string, null: false

      timestamps()
    end

    create unique_index(:boards, [:slug])
  end
end
