defmodule Fixture do
  import Koans, only: [__: 1]
  def list(_scope), do: __("07: list")
end

defmodule TaggedKoan do
  use Koans

  koan "lists" do
    assert Fixture.list(nil) == []
  end
end
