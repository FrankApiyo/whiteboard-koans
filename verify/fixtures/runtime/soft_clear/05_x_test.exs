defmodule SoftClear do
  import Koans, only: [__: 2]
  def notify(pid), do: __("05: notify", pid)
end

defmodule SoftClearKoan do
  use Koans

  koan "passes through a soft blank" do
    assert SoftClear.notify(:pid) == :pid
  end

  koan "fails on its own assertion" do
    assert 1 == 2
  end
end
