defmodule Easel.Shapes.Ellipse do
  use Ecto.Schema
  import Easel.Shapes.Validations

  @primary_key false
  embedded_schema do
    field :id, :string
    field :color, :string
    field :x, :integer
    field :y, :integer
    field :w, :integer
    field :h, :integer
  end

  def changeset(ellipse, attrs) do
    ellipse
    |> common_changeset(attrs, [:w, :h])
    |> validate_size([:w, :h])
    |> validate_extent(&extent/1)
  end

  defp extent(%{x: x, y: y, w: w, h: h}), do: {x, y, x + w, y + h}
end
