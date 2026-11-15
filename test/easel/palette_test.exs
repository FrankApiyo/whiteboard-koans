defmodule Easel.PaletteTest do
  use ExUnit.Case, async: true

  alias Easel.{Hello, Palette}

  test "the palette has eight hex colours and random picks one of them" do
    assert length(Palette.colors()) == 8
    assert Enum.all?(Palette.colors(), &String.match?(&1, ~r/^#[0-9a-f]{6}$/))
    assert Palette.random() in Palette.colors()
  end

  test "greet says hello" do
    assert Hello.greet("Ada") == "Hello, Ada!"
  end
end
