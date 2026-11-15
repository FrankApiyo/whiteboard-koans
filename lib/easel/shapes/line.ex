defmodule Easel.Shapes.Line do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  use Ecto.Schema
  import Ecto.Changeset, warn: false
  import Easel.Shapes.Validations, warn: false

  @fields [:id, :color, :x, :y, :dx, :dy]

  @primary_key false
  embedded_schema do
    field :id, Ecto.UUID
    field :color, :string
    field :x, :integer
    field :y, :integer
    field :dx, :integer
    field :dy, :integer
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> validate_shape()
    |> validate_extent(&extent/1)
  end

  defp validate_shape(changeset) do
    # >>> 07
    __("07: a line's palette colour")
    # <<< 07
  end

  defp extent(%{x: x, y: y, dx: dx, dy: dy}),
    do: {x + min(0, dx), y + min(0, dy), x + max(0, dx), y + max(0, dy)}
end
