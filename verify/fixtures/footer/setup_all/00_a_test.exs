defmodule SetupAllA do
  use Koans

  setup_all do
    raise "setup exploded"
  end

  koan "never runs" do
    assert true
  end
end
