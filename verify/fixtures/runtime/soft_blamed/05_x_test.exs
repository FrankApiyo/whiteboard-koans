defmodule SoftBlamed do
  import Koans, only: [__: 2]
  def notify(pid), do: __("05: notify", pid)
end

defmodule SoftBlamedKoan do
  use Koans

  koan "the chapter's own koan blames the blank" do
    SoftBlamed.notify(self())
    assert_received :notified
  end
end
