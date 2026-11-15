defmodule SoftWarn do
  use GenServer
  import Koans, only: [__: 2]

  def init(state), do: {:ok, state}
  def handle_info(_msg, socket), do: __("14: update", {:noreply, socket})

  def broadcast(topic, payload) do
    message = {topic, payload}
    __("14: broadcast", :ok)
  end
end

defmodule SoftWarnKoan do
  use Koans

  koan "defaulted blanks leave no warnings" do
    assert SoftWarn.broadcast("t", 1) == :ok
    assert SoftWarn.handle_info(:x, :socket) == {:noreply, :socket}
  end
end
