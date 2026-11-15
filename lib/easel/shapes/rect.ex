defmodule Easel.Shapes.Rect do
  use Ecto.Schema
  import Easel.Shapes.Validations

  @primary_key false
  embedded_schema do
    field :id, :string
    field :color, :string
    field :x, Easel.Shapes.StrictInteger
    field :y, Easel.Shapes.StrictInteger
    field :w, Easel.Shapes.StrictInteger
    field :h, Easel.Shapes.StrictInteger
  end

  def changeset(rect, attrs) do
    rect
    |> common_changeset(attrs, [:w, :h])
    |> validate_size([:w, :h])
    |> validate_extent(&extent/1)
  end

  defp extent(%{x: x, y: y, w: w, h: h}), do: {x, y, x + w, y + h}
end
