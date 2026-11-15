defmodule Easel.ShapesTest do
  use ExUnit.Case, async: true

  alias Easel.Shapes

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
  @color "#e03131"
  @base %{"id" => @id, "color" => @color, "x" => 10, "y" => 20}

  defp payload(kind, extra), do: @base |> Map.put("kind", kind) |> Map.merge(extra)

  describe "cast/1 per kind" do
    test "rect" do
      assert {:ok, shape} = Shapes.cast(payload("rect", %{"w" => 30, "h" => 40}))
      assert shape == %{id: @id, kind: "rect", color: @color, x: 10, y: 20, w: 30, h: 40}
    end

    test "ellipse" do
      assert {:ok, %{kind: "ellipse", w: 30, h: 40}} =
               Shapes.cast(payload("ellipse", %{"w" => 30, "h" => 40}))
    end

    test "line, which may run up and left" do
      assert {:ok, %{kind: "line", dx: -5, dy: -15}} =
               Shapes.cast(payload("line", %{"dx" => -5, "dy" => -15}))
    end

    test "pen" do
      assert {:ok, %{kind: "pen", points: [[1, 1], [2, 3]]}} =
               Shapes.cast(payload("pen", %{"points" => [[1, 1], [2, 3]]}))
    end
  end

  describe "hostile payloads at cast/1" do
    @rect %{"w" => 30, "h" => 40}

    test "non-UUID id" do
      assert {:error, _} = Shapes.cast(payload("rect", Map.put(@rect, "id", "nope")))
    end

    test "unknown kind and missing kind" do
      assert {:error, _} = Shapes.cast(payload("star", @rect))
      assert {:error, _} = Shapes.cast(Map.delete(payload("rect", @rect), "kind"))
    end

    test "float coordinate" do
      assert {:error, _} = Shapes.cast(payload("rect", Map.put(@rect, "x", 1.5)))
    end

    test "a numeric string is normalised to an integer" do
      assert {:ok, %{x: 5, w: 30}} =
               Shapes.cast(payload("rect", %{"w" => "30", "h" => 40, "x" => "5"}))

      assert {:error, _} = Shapes.cast(payload("rect", %{"w" => "abc", "h" => 1}))
    end

    test "negative and out of range origin" do
      assert {:error, _} = Shapes.cast(payload("rect", Map.put(@rect, "x", -1)))
      assert {:error, _} = Shapes.cast(payload("rect", Map.put(@rect, "y", 1001)))
    end

    test "extent that leaves the board even though the origin is inside" do
      assert {:error, _} = Shapes.cast(payload("rect", %{"w" => 1600, "h" => 40}))
      assert {:error, _} = Shapes.cast(payload("line", %{"dx" => 0, "dy" => 981}))
      assert {:error, _} = Shapes.cast(payload("line", %{"dx" => -11, "dy" => 0}))
    end

    test "a shape that fills the board exactly is fine" do
      assert {:ok, _} =
               Shapes.cast(
                 %{@base | "x" => 0, "y" => 0}
                 |> Map.merge(%{"kind" => "rect", "w" => 1600, "h" => 1000})
               )
    end

    test "colour outside the palette" do
      assert {:error, _} = Shapes.cast(payload("rect", Map.put(@rect, "color", "#000000")))
    end

    test "pen points over the cap" do
      points = List.duplicate([0, 0], 2001)
      assert {:error, _} = Shapes.cast(payload("pen", %{"points" => points}))
      assert {:ok, _} = Shapes.cast(payload("pen", %{"points" => List.duplicate([0, 0], 2000)}))
    end

    test "pen points that leave the board" do
      assert {:error, _} = Shapes.cast(payload("pen", %{"points" => [[-11, 0]]}))
      assert {:error, _} = Shapes.cast(payload("pen", %{"points" => [[0, 981]]}))
      assert {:error, _} = Shapes.cast(payload("pen", %{"points" => [[1591, 0]]}))
      assert {:error, _} = Shapes.cast(payload("pen", %{"points" => [[1, 2], [0, -21]]}))
      assert {:ok, _} = Shapes.cast(payload("pen", %{"points" => [[-10, 0], [0, 980]]}))
    end

    test "float pen points" do
      assert {:error, _} = Shapes.cast(payload("pen", %{"points" => [[1.5, 0]]}))
    end

    test "malformed pen points" do
      assert {:error, _} = Shapes.cast(payload("pen", %{"points" => [[1, 2, 3]]}))
      assert {:error, _} = Shapes.cast(payload("pen", %{"points" => []}))
    end

    test "missing key" do
      assert {:error, _} = Shapes.cast(payload("rect", %{"w" => 30}))
      assert {:error, _} = Shapes.cast(Map.delete(payload("rect", @rect), "color"))
    end

    test "zero or negative size" do
      assert {:error, _} = Shapes.cast(payload("rect", %{"w" => 0, "h" => 10}))
    end

    test "a payload that is not a map" do
      assert {:error, %Ecto.Changeset{valid?: false}} = Shapes.cast([1, 2])
      assert {:error, %Ecto.Changeset{valid?: false}} = Shapes.cast("rect")
    end
  end

  describe "board edges at cast/1" do
    test "an origin on the far edges is inside" do
      assert {:ok, %{x: 1600, y: 1000}} =
               Shapes.cast(payload("line", %{"x" => 1600, "y" => 1000, "dx" => 0, "dy" => 0}))
    end

    test "one past the far edges is outside" do
      assert {:error, _} =
               Shapes.cast(payload("line", %{"x" => 1601, "y" => 0, "dx" => 0, "dy" => 0}))

      assert {:error, _} =
               Shapes.cast(payload("line", %{"x" => 0, "y" => 1001, "dx" => 0, "dy" => 0}))
    end
  end

  describe "ids" do
    test "an upper-case id is stored normalised, so move and delete find the shape" do
      upper = String.upcase(@id)
      {:ok, shape} = Shapes.cast(payload("rect", %{"w" => 3, "h" => 4, "id" => upper}))

      assert shape.id == @id
      assert {:ok, @id} = Shapes.cast_id(%{"id" => upper})
      assert {:ok, %{id: @id}} = Shapes.cast_move(%{"id" => upper, "x" => 1, "y" => 1})
    end
  end

  describe "cast_move/1" do
    test "accepts an in-bounds origin" do
      assert {:ok, %{id: @id, x: 5, y: 6}} = Shapes.cast_move(%{"id" => @id, "x" => 5, "y" => 6})
    end

    test "accepts the far edges and rejects one past them" do
      assert {:ok, %{x: 1600, y: 1000}} =
               Shapes.cast_move(%{"id" => @id, "x" => 1600, "y" => 1000})

      assert :error = Shapes.cast_move(%{"id" => @id, "x" => 1601, "y" => 0})
      assert :error = Shapes.cast_move(%{"id" => @id, "x" => 0, "y" => 1001})
    end

    test "a numeric string is normalised to an integer, as in cast/1" do
      assert {:ok, %{x: 5, y: 6}} = Shapes.cast_move(%{"id" => @id, "x" => "5", "y" => 6})
      assert :error = Shapes.cast_move(%{"id" => @id, "x" => "abc", "y" => 6})
    end

    test "rejects hostile payloads" do
      assert :error = Shapes.cast_move([1, 2])
      assert :error = Shapes.cast_move(%{"id" => "nope", "x" => 5, "y" => 6})
      assert :error = Shapes.cast_move(%{"id" => @id, "x" => 1601, "y" => 6})
      assert :error = Shapes.cast_move(%{"id" => @id, "x" => 1.5, "y" => 6})
      assert :error = Shapes.cast_move(%{"id" => @id, "x" => 5})
    end
  end

  describe "cast_id/1" do
    test "accepts a UUID and rejects the rest" do
      assert {:ok, @id} = Shapes.cast_id(%{"id" => @id})
      assert :error = Shapes.cast_id(%{"id" => "nope"})
      assert :error = Shapes.cast_id(%{"id" => 5})
      assert :error = Shapes.cast_id(%{})
    end
  end
end
