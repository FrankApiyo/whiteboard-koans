defmodule Easel.Shapes.Validations do
  import Ecto.Changeset

  @width 1600
  @height 1000

  def validate_extent(%{valid?: false} = changeset, _extent_fun), do: changeset

  def validate_extent(changeset, extent_fun) do
    {left, top, right, bottom} = changeset |> apply_changes() |> extent_fun.()

    if left >= 0 and top >= 0 and right <= @width and bottom <= @height do
      changeset
    else
      add_error(changeset, :x, "extends outside the #{@width}x#{@height} board")
    end
  end
end
