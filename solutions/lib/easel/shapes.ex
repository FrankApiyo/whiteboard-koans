defmodule Easel.Shapes do
  import Ecto.Changeset

  alias Easel.Shapes.{Ellipse, Line, Pen, Rect, Validations}

  @kinds %{"rect" => Rect, "ellipse" => Ellipse, "line" => Line, "pen" => Pen}

  def cast(payload) when is_map(payload) do
    with {:ok, %{kind: kind}} <- cast_kind(payload) do
      cast_shape(Map.fetch!(@kinds, kind), kind, payload)
    end
  end

  def cast(_payload) do
    {%{}, %{}}
    |> change()
    |> add_error(:payload, "must be an object")
    |> apply_action(:cast)
  end

  def cast_move(payload) when is_map(payload) do
    move =
      {%{}, %{id: Ecto.UUID, x: :integer, y: :integer}}
      |> cast(payload, [:id, :x, :y])
      |> validate_required([:id, :x, :y])
      |> validate_number(:x,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: Validations.width()
      )
      |> validate_number(:y,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: Validations.height()
      )
      |> apply_action(:move)

    with {:error, _changeset} <- move, do: :error
  end

  def cast_move(_payload), do: :error

  def cast_id(%{"id" => id}) when is_binary(id), do: Ecto.UUID.cast(id)
  def cast_id(_payload), do: :error

  defp cast_shape(schema, kind, payload) do
    with {:ok, shape} <- schema |> struct() |> schema.changeset(payload) |> apply_action(:cast) do
      {:ok, shape |> Map.from_struct() |> Map.put(:kind, kind)}
    end
  end

  defp cast_kind(payload) do
    {%{}, %{kind: :string}}
    |> cast(payload, [:kind])
    |> validate_required(:kind)
    |> validate_inclusion(:kind, Map.keys(@kinds))
    |> apply_action(:cast)
  end
end
