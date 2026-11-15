defmodule Easel.Shapes do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  import Ecto.Changeset, warn: false

  alias Easel.Shapes.{Ellipse, Line, Pen, Rect, Validations}, warn: false

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
    # >>> 09
    __("09: cast id, x and y onto the board, or :error")
    # <<< 09
  end

  def cast_move(_payload), do: :error

  # >>> 09
  def cast_id(_payload), do: __("09: cast the id of any payload, or :error")
  # <<< 09

  defp cast_shape(schema, kind, payload) do
    # >>> 09
    __("09: the kind's changeset, applied, with the kind put back")
    # <<< 09
  end

  defp cast_kind(payload) do
    {%{}, %{kind: :string}}
    |> cast(payload, [:kind])
    |> validate_required(:kind)
    |> validate_inclusion(:kind, Map.keys(@kinds))
    |> apply_action(:cast)
  end
end
