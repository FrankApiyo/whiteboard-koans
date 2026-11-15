defmodule MultiA do
  use Koans

  koan "fails on the third line" do
    a = 1
    b = 2
    assert a + b == 4
    assert true
  end
end
