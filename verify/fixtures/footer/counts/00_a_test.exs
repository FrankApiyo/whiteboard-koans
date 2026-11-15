defmodule CountsA do
  use Koans

  koan "one" do
    assert true
  end

  koan "two" do
    assert true
  end

  koan "three" do
    assert true
  end

  koan "four fails" do
    assert 1 == 2
  end

  koan "five" do
    assert true
  end

  koan "six" do
    assert true
  end
end
