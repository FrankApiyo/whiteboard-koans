defmodule Easel.Shapes.Pen do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  use Ecto.Schema
  import Ecto.Changeset, warn: false
  import Easel.Shapes.Validations, warn: false

  @fields [:id, :color, :x, :y, :points]

  @primary_key false
  embedded_schema do
    field :id, Ecto.UUID
    field :color, :string
    field :x, :integer
    field :y, :integer
    field :points, {:array, {:array, :integer}}
  end

  def changeset(pen, attrs) do
    pen
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> validate_shape()
    |> validate_pairs()
    |> validate_extent(&extent/1)
  end

  defp validate_shape(changeset) do
    # >>> 07
    __("07: a pen's palette colour and 1 to 2000 points")
    # <<< 07
  end

  defp validate_pairs(changeset) do
    validate_change(changeset, :points, fn :points, points ->
      if Enum.all?(points, &integer_pair?/1), do: [], else: [points: "must be [dx, dy] pairs"]
    end)
  end

  defp integer_pair?([dx, dy]), do: is_integer(dx) and is_integer(dy)
  defp integer_pair?(_point), do: false

  defp extent(%{x: x, y: y, points: points}) do
    dxs = [0 | Enum.map(points, &hd/1)]
    dys = [0 | Enum.map(points, &List.last/1)]
    {x + Enum.min(dxs), y + Enum.min(dys), x + Enum.max(dxs), y + Enum.max(dys)}
  end
end
