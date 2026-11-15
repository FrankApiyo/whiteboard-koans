defmodule Easel.Boards.Ops do
  def apply(state, {:add, shape}) do
    # >>> answer 08: stamp z, keeping a known shape's z
    {z, next_z} =
      case Map.fetch(state.shapes, shape.id) do
        {:ok, known} -> {known.z, state.next_z}
        :error -> {state.next_z, state.next_z + 1}
      end

    stamped = Map.put(shape, :z, z)
    next = %{state | shapes: Map.put(state.shapes, shape.id, stamped), next_z: next_z}
    {:applied, next, "shape:added", stamped}
    # <<<
  end

  def apply(state, {:move, id, x, y}) do
    # >>> answer 08: move a known shape, ignore an unknown id
    case Map.fetch(state.shapes, id) do
      {:ok, shape} ->
        moved = %{shape | x: x, y: y}

        {:applied, %{state | shapes: Map.put(state.shapes, id, moved)}, "shape:moved",
         %{id: id, x: x, y: y}}

      :error ->
        {:ignored, state}
    end

    # <<<
  end

  def apply(state, {:delete, id}) do
    # >>> answer 08: delete a known shape, ignore an unknown id
    case Map.fetch(state.shapes, id) do
      {:ok, _shape} ->
        {:applied, %{state | shapes: Map.delete(state.shapes, id)}, "shape:deleted", %{id: id}}

      :error ->
        {:ignored, state}
    end

    # <<<
  end
end
