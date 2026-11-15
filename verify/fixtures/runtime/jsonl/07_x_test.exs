defmodule Fixture do
  import Koans, only: [__: 1]
  def list(_scope), do: __("07: list")
end

defmodule JsonlKoans do
  use Koans

  koan "passes" do
    assert true
  end

  koan "names its blank" do
    assert Fixture.list(nil) == []
  end

  koan "fails" do
    assert 1 == 1
    assert 1 === 1.0
  end

  koan "has a value blank" do
    assert 1 == __
  end
end
