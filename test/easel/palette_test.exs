defmodule Easel.PaletteTest do
  use ExUnit.Case, async: true

  alias Easel.Palette

  test "the palette has eight hex colours and random picks one of them" do
    assert length(Palette.colors()) == 8
    assert Enum.all?(Palette.colors(), &String.match?(&1, ~r/^#[0-9a-f]{6}$/))
    assert Palette.random() in Palette.colors()
  end
end
