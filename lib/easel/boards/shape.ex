defmodule Easel.Boards.Shape do
  use Ecto.Schema

  schema "shapes" do
    field :client_id, :string
    field :kind, :string
    field :color, :string
    field :z, :integer
    field :data, :map

    belongs_to :board, Easel.Boards.Board

    timestamps()
  end
end
