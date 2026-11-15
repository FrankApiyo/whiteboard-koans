defmodule Koans.Ch07.BoardsAndShapesInTheDatabaseTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel/boards/board.ex: Easel.Boards.Board.changeset/2
    - lib/easel/shapes/rect.ex: Easel.Shapes.Rect.validate_shape/1
    - lib/easel/shapes/ellipse.ex: Easel.Shapes.Ellipse.validate_shape/1
    - lib/easel/shapes/line.ex: Easel.Shapes.Line.validate_shape/1
    - lib/easel/shapes/pen.ex: Easel.Shapes.Pen.validate_shape/1
    - lib/easel/boards.ex: Easel.Boards.generate_slug/0, create_board/1, list_boards/1,
      load_shapes/1, save_shapes/2

  Boards and shapes live in two tables. The migrations and schemas are given: a board has a
  title and a slug with a unique index, and a shape row has board_id, client_id (a UUID the
  browser makes with crypto.randomUUID(), cast by each shape schema's Ecto.UUID id field), kind,
  color, z and data, a :map column that SQLite keeps as JSON text. JSON has no atoms, so a row
  read back has string keys in data: data["w"], while data[:w] is nil.

  Easel.Boards is the context, the one module the app calls for boards; Repo and queries stay
  inside it. Suppose a Pin schema had a label, a board_id and timestamps:

      def recent_pins(limit),
        do: Repo.all(from p in Pin, order_by: [desc: p.inserted_at], limit: ^limit)

  A slug is the board's address, so it must be unguessable: 16 random bytes, URL-safe base64
  with no padding, are 22 characters. Repo.transact(fun), the newer form of Repo.transaction/1
  with Repo.rollback/1, commits fun's work when fun returns {:ok, value} and rolls it all back on
  {:error, reason}. Each shape kind is an embedded_schema with no table: its changeset casts and
  requires its fields, then pipes them through its private validate_shape/1, Pen's
  validate_pairs and validate_extent.

      Write:          lib/easel/boards/board.ex:19  (Easel.Boards.Board.changeset/2)
      Exercised by:   test/koans/07_boards_and_shapes_in_the_database_test.exs:75

  API you'll use
    cast/3            cast(pin, %{"label" => "Door", "id" => 9}, [:label]) changes only label
    validate_required/2  validate_required(cs, [:label]) gives "can't be blank"
    validate_length/3  max: 40 gives "should be at most 40 character(s)"; on a list min: 2 gives
      "should have at least 2 item(s)" and max: 5 "should have at most 5 item(s)"
    validate_number/3  validate_number(cs, :size, greater_than: 0) gives "must be greater than 0"
    validate_inclusion/3  validate_inclusion(cs, :shade, ~w(light dark)) gives "is invalid"
    unique_constraint/2  unique_constraint(cs, :code) turns the index error into
      "has already been taken"
    :crypto.strong_rand_bytes/1  :crypto.strong_rand_bytes(4) is 4 random bytes
    Base.url_encode64/2  Base.url_encode64(<<251, 255>>, padding: false) is "-_8"
    Repo.insert/1     Repo.insert(changeset) is {:ok, struct} or {:error, changeset}
    Repo.all/1        Repo.all(from p in Pin, where: p.id in ^ids) is the pins with those ids
    Repo.delete_all/1  Repo.delete_all(from p in Pin, where: p.label == "old") is {count, nil}
    Repo.transact/1   Repo.transact(fn -> {:ok, 1} end) is {:ok, 1}
    Easel.Palette.colors/0  the eight palette colours, "#e03131" first
    errors_on/1       errors_on(cs) is %{label: ["can't be blank"]}
    shape_fixture/2   shape_fixture(board, z: 2) inserts a rect row,
      data %{x: 10, y: 10, w: 100, h: 50}

  Picture: none for this chapter; Easel's two tables are in priv/repo/migrations.
  """
  use Koans, case: Easel.DataCase

  import Easel.BoardsFixtures

  alias Easel.Boards
  alias Easel.Boards.{Board, Shape}
  alias Easel.Shapes.{Ellipse, Line, Pen, Rect}

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"

  koan "A shape row keeps its geometry in data, a :map column stored as JSON: the struct you insert holds atom keys, and the row read back holds strings." do
    inserted = shape_fixture(board_fixture())
    data = Repo.get!(Shape, inserted.id).data

    assert inserted.data[:w] == __
    assert data["w"] == __
    assert data[:w] == __
  end

  koan "Implement Board.changeset/2 so a board takes only its title from outside, needs a title and a slug, keeps the title to 80 characters, and reports a taken slug as an error. 1. Cast just the title. 2. Require the title and the slug. 3. Cap the title's length. 4. Add a unique constraint on the slug." do
    ok = Board.changeset(%Board{slug: "kept"}, %{"title" => "Plan", "slug" => "mine"})
    assert ok.valid?
    assert get_field(ok, :slug) == "kept"

    assert Board.changeset(%Board{slug: "s"}, %{"title" => String.duplicate("a", 80)}).valid?
    long = %{"title" => String.duplicate("a", 81)}
    too_long = %{title: ["should be at most 80 character(s)"]}
    assert errors_on(Board.changeset(%Board{slug: "s"}, long)) == too_long
    assert errors_on(Board.changeset(%Board{slug: "s"}, %{"title" => ""})) == %{title: ["can't be blank"]}
    assert errors_on(Board.changeset(%Board{}, %{"title" => "Plan"})) == %{slug: ["can't be blank"]}

    taken = board_fixture()
    copy = Board.changeset(%Board{slug: taken.slug}, %{"title" => "Copy"})
    assert {:error, changeset} = Repo.insert(copy)
    assert errors_on(changeset) == %{slug: ["has already been taken"]}
  end

  koan "Implement Boards.generate_slug/0 so each slug is 16 random bytes in URL-safe base64 with no padding: 22 characters of letters, digits, - and _, new on every call." do
    slug = Boards.generate_slug()

    assert slug =~ ~r/\A[A-Za-z0-9_-]{22}\z/
    assert byte_size(Base.url_decode64!(slug, padding: false)) == 16
    refute slug == Boards.generate_slug()
  end

  koan "Implement Boards.create_board/1 so it inserts a board with a fresh slug and the title from attrs, and hands back the changeset when the title won't do. A slug in attrs is ignored." do
    assert {:ok, board} = Boards.create_board(%{"title" => "Plan", "slug" => "chosen"})
    assert board.title == "Plan"
    assert String.length(board.slug) == 22
    assert Boards.get_board_by_slug!(board.slug).id == board.id

    assert {:error, %Ecto.Changeset{} = changeset} = Boards.create_board(%{"title" => ""})
    assert errors_on(changeset) == %{title: ["can't be blank"]}
  end

  koan "Implement Boards.list_boards/1 so it returns the boards whose slugs are in the list, sorted by slug, and skips a slug with no board." do
    second = board_fixture(slug: "b-board")
    first = board_fixture(slug: "a-board")
    board_fixture(slug: "c-board")

    listed = Boards.list_boards(["b-board", "gone", "a-board"])
    assert Enum.map(listed, & &1.id) == [first.id, second.id]
    assert Boards.list_boards([]) == []
  end

  koan "Implement the query at the head of Boards.load_shapes/1 so it reads this board's rows only, lowest z first. The given to_map/1 turns each row into the map the board keeps: data's keys as atoms, and client_id as id." do
    board = board_fixture()
    top = shape_fixture(board, z: 2, color: "#1971c2")
    bottom = shape_fixture(board, z: 1)
    shape_fixture(board_fixture())

    assert [first, second] = Boards.load_shapes(board)
    expected = %{id: bottom.client_id, kind: "rect", color: "#e03131", z: 1, x: 10, y: 10}
    assert first == Map.merge(expected, %{w: 100, h: 50})
    assert {second.id, second.color} == {top.client_id, "#1971c2"}
  end

  koan "Repo.transact commits only when its function returns {:ok, value}; on {:error, reason} it rolls back what the function did and returns the error." do
    kept = Repo.transact(fn -> {:ok, Repo.insert!(%Board{title: "Kept", slug: "kept"})} end)

    dropped =
      Repo.transact(fn ->
        Repo.insert!(%Board{title: "Dropped", slug: "dropped"})
        {:error, :changed_my_mind}
      end)

    assert {:ok, %Board{}} = kept
    assert dropped == {:error, :changed_my_mind}
    assert Repo.get_by(Board, slug: "kept").title == __
    assert Repo.get_by(Board, slug: "dropped") == __
  end

  koan "Implement the delete in Boards.save_shapes/2 so a save replaces every row of the board in one transaction: the old rows go, the new ones go in, other boards keep theirs, and the count saved comes back." do
    board = board_fixture()
    other = board_fixture()
    shape_fixture(board)
    kept = shape_fixture(other)
    shapes = [%{id: @id, kind: "line", color: "#2f9e44", z: 0, x: 5, y: 5, dx: 10, dy: -5}]

    assert Boards.save_shapes(board, shapes) == {:ok, 1}
    assert Boards.save_shapes(board, shapes) == {:ok, 1}
    assert Boards.load_shapes(board) == shapes
    assert Enum.map(Boards.load_shapes(other), & &1.id) == [kept.client_id]
  end

  koan "Implement validate_shape/1 in Rect and in Ellipse so a box must be in a palette colour and have a width and a height above 0. 1. Check the colour is in Easel.Palette.colors(). 2. Check w and h are each greater than 0." do
    box = %{"id" => @id, "color" => "#e03131", "x" => 10, "y" => 20, "w" => 30, "h" => 40}

    assert Rect.changeset(%Rect{}, box).valid?
    assert Ellipse.changeset(%Ellipse{}, box).valid?
    assert Rect.changeset(%Rect{}, %{box | "w" => 1}).valid?
    assert errors_on(Rect.changeset(%Rect{}, %{box | "w" => 0})) == %{w: ["must be greater than 0"]}
    assert errors_on(Rect.changeset(%Rect{}, %{box | "color" => "#000000"})) == %{color: ["is invalid"]}
    assert errors_on(Rect.changeset(%Rect{}, %{box | "h" => 0})) == %{h: ["must be greater than 0"]}
    assert errors_on(Ellipse.changeset(%Ellipse{}, %{box | "w" => 0})) == %{w: ["must be greater than 0"]}
    assert errors_on(Ellipse.changeset(%Ellipse{}, %{box | "h" => 0})) == %{h: ["must be greater than 0"]}
    assert errors_on(Ellipse.changeset(%Ellipse{}, %{box | "color" => "red"})) == %{color: ["is invalid"]}
  end

  koan "Implement validate_shape/1 in Line and in Pen so a line must be in a palette colour, and a pen too, with 1 to 2000 points." do
    line = %{"id" => @id, "color" => "#2f9e44", "x" => 100, "y" => 100, "dx" => -40, "dy" => 30}
    pen = %{"id" => @id, "color" => "#7048e8", "x" => 10, "y" => 10, "points" => [[5, 5], [9, 0]]}
    most = List.duplicate([0, 0], 2000)

    assert Line.changeset(%Line{}, line).valid?
    assert errors_on(Line.changeset(%Line{}, %{line | "color" => "red"})) == %{color: ["is invalid"]}
    assert Pen.changeset(%Pen{}, pen).valid?
    assert Pen.changeset(%Pen{}, %{pen | "points" => most}).valid?
    assert errors_on(Pen.changeset(%Pen{}, %{pen | "color" => "red"})) == %{color: ["is invalid"]}
    fewest = %{points: ["should have at least 1 item(s)"]}
    assert errors_on(Pen.changeset(%Pen{}, %{pen | "points" => []})) == fewest
    too_many = %{points: ["should have at most 2000 item(s)"]}
    assert errors_on(Pen.changeset(%Pen{}, %{pen | "points" => [[0, 0] | most]})) == too_many
  end
end
