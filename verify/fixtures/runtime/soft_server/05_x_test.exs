defmodule SoftServer do
  use GenServer
  import Koans, only: [__: 2]

  def start_link(state), do: GenServer.start_link(__MODULE__, state)
  def init(state), do: {:ok, state}
  def handle_call(:bump, _from, count), do: __("05: bump", {:reply, count, count})
end

defmodule SoftServerKoan do
  use Koans

  koan "a blank in another process is attributed" do
    pid = start_supervised!({SoftServer, 0})
    GenServer.call(pid, :bump)
    assert GenServer.call(pid, :bump) == 2
  end
end
