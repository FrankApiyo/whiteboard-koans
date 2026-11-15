defmodule Easel.Palette do
  @colors ~w(#e03131 #f08c00 #fab005 #2f9e44 #1098ad #1971c2 #7048e8 #c2255c)

  def colors, do: @colors

  def random, do: Enum.random(@colors)

  def member?(color), do: color in @colors
end
