defmodule SameChapter do
  use Koans

  koan "an answered koan" do
    assert true
  end

  koan "a blank koan" do
    assert 1 == __
  end
end
