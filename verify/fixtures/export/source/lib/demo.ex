defmodule Demo do
  import Enum

  def add(a, b) do
    # >>> answer 01: add
    a + b
    # <<<
  end

  # >>> answer 02: kinds | stub: def kind(_x)
  def kind(1), do: :one
  def kind(_), do: :many
  # <<<

  def notify(x) do
    # >>> answer 03: notify | default: :ok
    send(self(), {:note, x})
    # <<<
  end
end
