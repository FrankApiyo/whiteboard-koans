defmodule Easel.Boards.Ops do
  def apply(state, {:add, shape}) do
    stamped = Map.put(shape, :z, state.next_z)
    next = %{state | shapes: Map.put(state.shapes, shape.id, stamped), next_z: state.next_z + 1}
    {:applied, next, "shape:added", stamped}
  end

  def apply(state, {:move, id, x, y}) do
    case state.shapes do
      %{^id => shape} ->
        moved = %{shape | x: x, y: y}

        {:applied, %{state | shapes: Map.put(state.shapes, id, moved)}, "shape:moved",
         %{id: id, x: x, y: y}}

      _unknown ->
        {:ignored, state}
    end
  end

  def apply(state, {:delete, id}) do
    if Map.has_key?(state.shapes, id) do
      {:applied, %{state | shapes: Map.delete(state.shapes, id)}, "shape:deleted", %{id: id}}
    else
      {:ignored, state}
    end
  end
end
