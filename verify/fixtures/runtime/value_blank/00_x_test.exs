defmodule ValueBlankKoan do
  use Koans

  koan "a sum" do
    x = 1
    assert x == 1
    assert 1 + 1 == __
  end
end
