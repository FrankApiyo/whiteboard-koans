defmodule Easel.Shapes.Pen do
  use Ecto.Schema
  import Ecto.Changeset
  import Easel.Shapes.Validations

  @max_points 2000

  @primary_key false
  embedded_schema do
    field :id, :string
    field :color, :string
    field :x, Easel.Shapes.StrictInteger
    field :y, Easel.Shapes.StrictInteger
    field :points, {:array, {:array, Easel.Shapes.StrictInteger}}
  end

  def max_points, do: @max_points

  def changeset(pen, attrs) do
    pen
    |> common_changeset(attrs, [:points])
    |> validate_length(:points, min: 1, max: @max_points)
    |> validate_pairs()
    |> validate_extent(&extent/1)
  end

  defp validate_pairs(changeset) do
    validate_change(changeset, :points, fn :points, points ->
      if Enum.all?(points, &match?([_, _], &1)), do: [], else: [points: "must be [dx, dy] pairs"]
    end)
  end

  defp extent(%{x: x, y: y, points: points}) do
    dxs = [0 | Enum.map(points, &hd/1)]
    dys = [0 | Enum.map(points, &List.last/1)]
    {x + Enum.min(dxs), y + Enum.min(dys), x + Enum.max(dxs), y + Enum.max(dys)}
  end
end
