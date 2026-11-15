defmodule NoWarningsServer do
  use GenServer
  import Koans, only: [__: 0]

  def init(state), do: {:ok, state}
  def handle_call(_request, _from, _state), do: __()
  def greet(name), do: __()
end

defmodule NoWarningsKoan do
  use Koans

  koan "passes when nothing is blank" do
    assert 1 + 1 == 2
  end
end
