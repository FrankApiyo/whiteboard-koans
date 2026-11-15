defmodule TimeoutA do
  use Koans


  koan "waits forever" do
    receive do :never -> :ok end
  end
end
