defmodule Easel.Shapes.Validations do
  import Ecto.Changeset

  @width 1600
  @height 1000

  def width, do: @width
  def height, do: @height

  def common_changeset(struct, attrs, extra_fields) do
    struct
    |> cast(attrs, [:id, :color, :x, :y] ++ extra_fields)
    |> validate_required([:id, :color, :x, :y] ++ extra_fields)
    |> validate_id()
    |> validate_inclusion(:color, Easel.Palette.colors())
  end

  def validate_size(changeset, fields) do
    Enum.reduce(fields, changeset, &validate_number(&2, &1, greater_than: 0))
  end

  def validate_extent(%{valid?: false} = changeset, _extent_fun), do: changeset

  def validate_extent(changeset, extent_fun) do
    {left, top, right, bottom} = changeset |> apply_changes() |> extent_fun.()

    if left >= 0 and top >= 0 and right <= @width and bottom <= @height do
      changeset
    else
      add_error(changeset, :x, "extends outside the #{@width}x#{@height} board")
    end
  end

  defp validate_id(changeset) do
    validate_change(changeset, :id, fn :id, id ->
      case Ecto.UUID.cast(id) do
        {:ok, _uuid} -> []
        :error -> [id: "is not a UUID"]
      end
    end)
  end
end
