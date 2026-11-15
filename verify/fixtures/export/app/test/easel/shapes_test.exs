defmodule Demo.ShapesTest do
  use ExUnit.Case

  test "doubles" do
    assert Demo.Helper.double(2) == 4
  end
end
