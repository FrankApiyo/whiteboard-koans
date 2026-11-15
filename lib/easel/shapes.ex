defmodule Easel.Shapes do
  import Ecto.Changeset

  alias Easel.Shapes.{Ellipse, Line, Pen, Rect}

  @kinds %{"rect" => Rect, "ellipse" => Ellipse, "line" => Line, "pen" => Pen}

  def cast(payload) do
    with {:ok, %{kind: kind}} <- cast_kind(payload),
         schema = Map.fetch!(@kinds, kind),
         {:ok, shape} <- schema |> struct() |> schema.changeset(payload) |> apply_action(:cast) do
      {:ok, shape |> Map.from_struct() |> Map.put(:kind, kind)}
    end
  end

  def cast_move(%{"id" => id, "x" => x, "y" => y})
      when is_integer(x) and is_integer(y) and x in 0..1600 and y in 0..1000 do
    with {:ok, id} <- cast_id(%{"id" => id}), do: {:ok, %{id: id, x: x, y: y}}
  end

  def cast_move(_payload), do: :error

  def cast_id(%{"id" => id}) when is_binary(id), do: Ecto.UUID.cast(id)
  def cast_id(_payload), do: :error

  defp cast_kind(payload) do
    {%{}, %{kind: :string}}
    |> cast(payload, [:kind])
    |> validate_required(:kind)
    |> validate_inclusion(:kind, Map.keys(@kinds))
    |> apply_action(:cast)
  end
end
