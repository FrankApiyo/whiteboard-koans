defmodule Easel.BoardsTest do
  use Easel.DataCase

  import Easel.BoardsFixtures

  alias Easel.Boards
  alias Easel.Boards.Shape

  test "generate_slug is 22 url-safe characters and unique" do
    slug = Boards.generate_slug()
    assert slug =~ ~r/^[A-Za-z0-9_-]{22}$/
    refute slug == Boards.generate_slug()
  end

  test "create_board generates a slug and validates the title" do
    assert {:ok, board} = Boards.create_board(%{"title" => "Plan"})
    assert board.slug =~ ~r/^[A-Za-z0-9_-]{22}$/
    assert {:ok, chosen} = Boards.create_board(%{"title" => "Plan", "slug" => "mine"})
    refute chosen.slug == "mine"
    assert {:error, changeset} = Boards.create_board(%{"title" => ""})
    assert %{title: ["can't be blank"]} = errors_on(changeset)
  end

  test "get_board_by_slug! finds a board and raises for an unknown slug" do
    board = board_fixture()
    assert Boards.get_board_by_slug!(board.slug).id == board.id
    assert_raise Ecto.NoResultsError, fn -> Boards.get_board_by_slug!("missing") end
  end

  test "list_boards returns the named boards in slug order" do
    for slug <- ~w(c a b d), do: board_fixture(slug: slug)
    slugs = ~w(c a b) ++ ["unknown"]

    assert Enum.map(Boards.list_boards(slugs), & &1.slug) == ~w(a b c)
    assert Boards.list_boards([]) == []
  end

  describe "shapes" do
    @id1 "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
    @id2 "7f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"

    test "save_shapes then load_shapes round trips, in z order" do
      board = board_fixture()
      pen = %{id: @id2, kind: "pen", color: "#2f9e44", z: 0, x: 1, y: 2, points: [[1, 1], [2, 3]]}
      rect = %{id: @id1, kind: "rect", color: "#e03131", z: 1, x: 5, y: 6, w: 7, h: 8}

      assert {:ok, _} = Boards.save_shapes(board, [rect, pen])
      assert Boards.load_shapes(board) == [pen, rect]
    end

    test "save_shapes replaces every existing row" do
      board = board_fixture()
      shape_fixture(board)
      shape_fixture(board)
      rect = %{id: @id1, kind: "rect", color: "#e03131", z: 0, x: 5, y: 6, w: 7, h: 8}

      {:ok, _} = Boards.save_shapes(board, [rect])

      assert [%{id: @id1}] = Boards.load_shapes(board)
      assert Repo.aggregate(Shape, :count) == 1
    end

    # A pen's points bind as one JSON value, so a row binds one variable per column.
    test "save_shapes saves more shapes than one insert can bind" do
      board = board_fixture()
      columns_per_row = 6
      count = div(32_766, columns_per_row) + 1
      points = Enum.map(1..50, &[&1, &1])

      pens =
        for z <- 1..count do
          %{id: "pen-#{z}", kind: "pen", color: "#2f9e44", z: z, x: 0, y: 0, points: points}
        end

      assert count * columns_per_row > 32_766
      assert {:ok, ^count} = Boards.save_shapes(board, pens)
      assert length(Boards.load_shapes(board)) == count
    end

    test "save_shapes leaves other boards alone" do
      board = board_fixture()
      other = board_fixture()
      shape_fixture(other)

      {:ok, _} = Boards.save_shapes(board, [])

      assert length(Boards.load_shapes(other)) == 1
    end

    test "a failing save rolls back the delete" do
      board = board_fixture()
      shape_fixture(board)
      rect = %{id: @id1, kind: "rect", color: "#e03131", z: 0, x: 5, y: 6, w: 7, h: 8}

      assert_raise Exqlite.Error, fn -> Boards.save_shapes(board, [rect, rect]) end
      assert length(Boards.load_shapes(board)) == 1
    end
  end

  test "broadcast_op reaches subscribers of the board topic" do
    Boards.subscribe("abc")
    Boards.broadcast_op("abc", {:board_op, "shape:deleted", %{id: "x"}})
    assert_receive {:board_op, "shape:deleted", %{id: "x"}}

    Boards.broadcast_op("other", {:board_op, "shape:deleted", %{id: "y"}})
    refute_receive {:board_op, _, %{id: "y"}}, 50
  end
end
