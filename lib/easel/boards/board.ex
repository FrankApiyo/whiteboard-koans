defmodule Easel.Boards.Board do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "boards" do
    field :title, :string
    field :slug, :string

    has_many :shapes, Easel.Boards.Shape

    timestamps()
  end

  def changeset(board, attrs) do
    # >>> 07
    __("07: cast the title, then check title and slug")
    # <<< 07
  end
end
