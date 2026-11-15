defmodule LinkedCrashA do
  use Koans

  koan "a linked process raises" do
    spawn_link(fn -> raise "boom" end)
    Process.sleep(500)
  end
end
