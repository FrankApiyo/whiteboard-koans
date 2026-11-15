defmodule Easel.Repo.Migrations.CreateShapes do
  use Ecto.Migration

  def change do
    create table(:shapes) do
      add :board_id, references(:boards, on_delete: :delete_all), null: false
      add :client_id, :string, null: false
      add :kind, :string, null: false
      add :color, :string, null: false
      add :z, :integer, null: false
      add :data, :map, null: false
    end

    create unique_index(:shapes, [:board_id, :client_id])
  end
end
