defmodule EnlightWithWarnings do
  use Koans

  koan "an answered koan" do
    unused = 1
    assert true
  end

  koan "a filled koan" do
    assert 1 == 1
  end
end
