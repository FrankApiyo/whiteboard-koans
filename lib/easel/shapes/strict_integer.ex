defmodule Easel.Shapes.StrictInteger do
  use Ecto.Type

  def type, do: :integer

  def cast(value) when is_integer(value), do: {:ok, value}
  def cast(_value), do: :error

  def load(value), do: {:ok, value}
  def dump(value) when is_integer(value), do: {:ok, value}
  def dump(_value), do: :error
end
