defmodule SoftDefault do
  import Koans, only: [__: 2]
  def subscribe(socket), do: __("05: subscribe", socket)
end

defmodule SoftDefaultKoan do
  use Koans

  koan "an earlier path keeps working" do
    assert SoftDefault.subscribe(:socket) == :socket
  end
end
