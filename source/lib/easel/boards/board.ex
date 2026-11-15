defmodule Easel.Boards.Board do
  use Ecto.Schema
  import Ecto.Changeset

  schema "boards" do
    field :title, :string
    field :slug, :string

    has_many :shapes, Easel.Boards.Shape

    timestamps()
  end

  def changeset(board, attrs) do
    # >>> answer 07: cast the title, then check title and slug
    board
    |> cast(attrs, [:title])
    |> validate_required([:title, :slug])
    |> validate_length(:title, max: 80)
    |> unique_constraint(:slug)

    # <<<
  end
end
