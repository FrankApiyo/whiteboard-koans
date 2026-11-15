defmodule ReceiveA do
  use Koans

  koan "expects a message" do
    assert_receive :never_sent, 50
  end
end
