defmodule BlankServer do
  use GenServer
  import Koans, only: [__: 0]

  def start_link(state), do: GenServer.start_link(__MODULE__, state)
  def init(state), do: {:ok, state}
  def handle_call(_request, _from, _state), do: __()
end

defmodule GenServerKoan do
  use Koans

  koan "calls a server" do
    pid = start_supervised!({BlankServer, []})
    assert GenServer.call(pid, :ping) == :pong
  end
end
