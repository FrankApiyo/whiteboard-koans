defmodule SoftTwo do
  import Koans, only: [__: 2]
  def first(pid), do: __("05: first", pid)
  def second(pid), do: __("05: second", pid)
end

defmodule SoftTwoKoan do
  use Koans

  koan "the first soft blank is named" do
    SoftTwo.first(self())
    SoftTwo.second(self())
    assert_received :never
  end
end
