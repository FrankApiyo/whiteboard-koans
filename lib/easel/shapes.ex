defmodule Easel.Shapes do
  alias Easel.Shapes.{Ellipse, Line, Pen, Rect}

  @kinds %{"rect" => Rect, "ellipse" => Ellipse, "line" => Line, "pen" => Pen}

  def cast(%{"kind" => kind} = payload) when is_map_key(@kinds, kind) do
    schema = Map.fetch!(@kinds, kind)
    changeset = schema.changeset(struct(schema), payload)

    with {:ok, shape} <- Ecto.Changeset.apply_action(changeset, :cast) do
      {:ok, shape |> Map.from_struct() |> Map.put(:kind, kind)}
    end
  end

  def cast(_payload) do
    changeset =
      {%{}, %{kind: :string}}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(:kind, "is not a known shape kind")

    {:error, %{changeset | action: :cast}}
  end

  def cast_move(%{"id" => id, "x" => x, "y" => y})
      when is_integer(x) and is_integer(y) and x in 0..1600 and y in 0..1000 do
    with {:ok, id} <- cast_id(%{"id" => id}), do: {:ok, %{id: id, x: x, y: y}}
  end

  def cast_move(_payload), do: :error

  def cast_id(%{"id" => id}) when is_binary(id), do: Ecto.UUID.cast(id)
  def cast_id(_payload), do: :error
end
