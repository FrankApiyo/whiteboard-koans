defmodule Easel.HelloTest do
  use ExUnit.Case, async: true

  test "greet says hello" do
    assert Easel.Hello.greet("Ada") == "Hello, Ada!"
  end
end
