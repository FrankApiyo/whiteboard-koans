defmodule Easel.Shapes.Line do
  use Ecto.Schema
  import Easel.Shapes.Validations

  @primary_key false
  embedded_schema do
    field :id, :string
    field :color, :string
    field :x, :integer
    field :y, :integer
    field :dx, :integer
    field :dy, :integer
  end

  def changeset(line, attrs) do
    line
    |> common_changeset(attrs, [:dx, :dy])
    |> validate_extent(&extent/1)
  end

  defp extent(%{x: x, y: y, dx: dx, dy: dy}),
    do: {x + min(0, dx), y + min(0, dy), x + max(0, dx), y + max(0, dy)}
end
