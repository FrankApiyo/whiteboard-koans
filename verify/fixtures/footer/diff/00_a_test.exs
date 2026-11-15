defmodule DiffA do
  use Koans


  koan "int is not float" do
    assert 1 === 1.0
  end
end
