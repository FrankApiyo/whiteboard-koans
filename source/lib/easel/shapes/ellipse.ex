defmodule Easel.Shapes.Ellipse do
  use Ecto.Schema
  import Ecto.Changeset
  import Easel.Shapes.Validations

  @fields [:id, :color, :x, :y, :w, :h]

  @primary_key false
  embedded_schema do
    field :id, Ecto.UUID
    field :color, :string
    field :x, :integer
    field :y, :integer
    field :w, :integer
    field :h, :integer
  end

  def changeset(ellipse, attrs) do
    ellipse
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> validate_inclusion(:color, Easel.Palette.colors())
    |> validate_number(:w, greater_than: 0)
    |> validate_number(:h, greater_than: 0)
    |> validate_extent(&extent/1)
  end

  defp extent(%{x: x, y: y, w: w, h: h}), do: {x, y, x + w, y + h}
end
