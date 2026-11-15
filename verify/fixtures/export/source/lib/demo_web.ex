defmodule DemoWeb do
  def html_helpers do
    quote do
      import Phoenix.HTML

      # >>> course
      import Koans, only: [__: 1, __: 2], warn: false
      # <<< course
    end
  end
end
