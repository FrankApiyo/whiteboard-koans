defmodule Easel.Boards.Ops do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  def apply(state, {:add, shape}) do
    # >>> 08
    __("08: stamp z, keeping a known shape's z")
    # <<< 08
  end

  def apply(state, {:move, id, x, y}) do
    # >>> 08
    __("08: move a known shape, ignore an unknown id")
    # <<< 08
  end

  def apply(state, {:delete, id}) do
    # >>> 08
    __("08: delete a known shape, ignore an unknown id")
    # <<< 08
  end
end
