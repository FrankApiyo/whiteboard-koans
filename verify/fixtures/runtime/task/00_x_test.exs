defmodule BlankWork do
  import Koans, only: [__: 0]
  def run(_input), do: __()
end

defmodule TaskKoan do
  use Koans

  koan "awaits a task" do
    assert Task.async(fn -> BlankWork.run(1) end) |> Task.await() == 2
  end
end
