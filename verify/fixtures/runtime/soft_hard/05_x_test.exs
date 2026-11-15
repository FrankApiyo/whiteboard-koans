defmodule SoftHard do
  import Koans, only: [__: 1, __: 2]
  def hard, do: __("05: hard")
  def soft(pid), do: __("05: soft", pid)
end

defmodule SoftHardKoan do
  use Koans

  koan "a hard blank wins over a later soft one" do
    try do
      SoftHard.hard()
    rescue
      _ -> :ignored
    end

    SoftHard.soft(self())
    assert_received :never
  end
end
