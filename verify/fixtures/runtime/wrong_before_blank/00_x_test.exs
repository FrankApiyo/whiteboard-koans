defmodule WrongBeforeBlankKoan do
  use Koans

  koan "wrong answer first" do
    x = 1
    assert 1 == 2
    assert x == __
  end
end
