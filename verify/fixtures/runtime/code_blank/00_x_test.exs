defmodule CodeBlankKoan do
  use Koans
  @moduledoc false

  def greet(name), do: __()

  koan "greets" do
    assert greet("Ann") == "Hello, Ann"
  end
end
