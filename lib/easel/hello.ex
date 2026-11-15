defmodule Easel.Hello do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  @moduledoc false

  def greet(name) do
    # >>> 00
    __("00: say hello")
    # <<< 00
  end
end
