defmodule Easel.Boards.OpsTest do
  use ExUnit.Case, async: true

  alias Easel.Boards.Ops

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
  @shape %{id: @id, kind: "rect", color: "#e03131", x: 1, y: 2, w: 3, h: 4}
  @empty %{shapes: %{}, next_z: 0}

  test "add assigns z and reports the event" do
    assert {:applied, state, "shape:added", payload} = Ops.apply(@empty, {:add, @shape})
    assert payload == Map.put(@shape, :z, 0)
    assert state.next_z == 1
  end

  test "adding twice leaves one shape" do
    {:applied, once, _, _} = Ops.apply(@empty, {:add, @shape})
    {:applied, twice, _, _} = Ops.apply(once, {:add, @shape})
    assert map_size(twice.shapes) == 1
  end

  test "move updates the origin" do
    {:applied, state, _, _} = Ops.apply(@empty, {:add, @shape})

    assert {:applied, moved, "shape:moved", %{id: @id, x: 9, y: 8}} =
             Ops.apply(state, {:move, @id, 9, 8})

    assert %{x: 9, y: 8} = moved.shapes[@id]
  end

  test "delete removes the shape" do
    {:applied, state, _, _} = Ops.apply(@empty, {:add, @shape})
    assert {:applied, gone, "shape:deleted", %{id: @id}} = Ops.apply(state, {:delete, @id})
    assert gone.shapes == %{}
  end

  test "move and delete of an unknown id are ignored" do
    assert {:ignored, @empty} = Ops.apply(@empty, {:move, @id, 1, 1})
    assert {:ignored, @empty} = Ops.apply(@empty, {:delete, @id})
  end

  test "delete then move does not re-create the shape" do
    {:applied, state, _, _} = Ops.apply(@empty, {:add, @shape})
    {:applied, gone, _, _} = Ops.apply(state, {:delete, @id})
    assert {:ignored, after_move} = Ops.apply(gone, {:move, @id, 5, 5})
    assert after_move.shapes == %{}
  end
end
