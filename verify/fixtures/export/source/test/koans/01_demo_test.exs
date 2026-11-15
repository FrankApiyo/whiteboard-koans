defmodule Koans.Ch01.DemoTest do
  use Koans

  koan "adds" do
    assert Demo.add(1, 2) == _a(3)
  end
end
