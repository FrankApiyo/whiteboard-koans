defmodule Easel.Shapes.Rect do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  use Ecto.Schema
  import Ecto.Changeset, warn: false
  import Easel.Shapes.Validations, warn: false

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

  def changeset(rect, attrs) do
    rect
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> validate_shape()
    |> validate_extent(&extent/1)
  end

  defp validate_shape(changeset) do
    # >>> 07
    __("07: a rect's palette colour and positive size")
    # <<< 07
  end

  defp extent(%{x: x, y: y, w: w, h: h}), do: {x, y, x + w, y + h}
end
