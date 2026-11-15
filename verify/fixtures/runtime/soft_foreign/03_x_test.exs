defmodule SoftForeign do
  import Koans, only: [__: 2]
  def notify(pid), do: __("05: notify", pid)
end

defmodule SoftForeignKoan do
  use Koans

  koan "a wrong value stays a wrong value" do
    SoftForeign.notify(self())
    assert 1 == 2
  end
end
