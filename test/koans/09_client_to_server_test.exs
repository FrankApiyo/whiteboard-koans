defmodule Koans.Ch09.ClientToServerTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel/shapes.ex: Easel.Shapes.cast_shape/3, cast_move/1, cast_id/1
    - lib/easel_web/live/board_live.ex: EaselWeb.BoardLive.handle_event/3

  The server checks every change before the board sees it. A push reaches handle_event/3 as
  string keys and JSON values from a browser anyone can script, so nothing in it is trusted.
  Shapes.cast/1 reads kind with cast_kind/1, a schemaless changeset: a {data, types} pair
  stands in for a struct, so cast/3 and the validations work with no schema module. Then the
  kind's embedded schema (chapter 07) runs. apply_action/2 ends both without a database:
  {:ok, data} or {:error, changeset}. An :integer field casts "5" to 5 and refuses 10.5, and
  Ecto.UUID.cast/1 checks the id the browser made. cast/3 keeps only the listed keys; the rest
  fall away. A vote, for one:

      {%{}, %{choice: :integer}}
      |> cast(params, [:choice])
      |> validate_number(:choice, greater_than: 0, less_than_or_equal_to: 5)
      |> apply_action(:vote)

  handle_event/3 answers {:reply, map, socket}, and the map reaches the pushEvent's onReply.
  Given helpers build it: run_op/3 applies an op and answers %{ok: true}, or the server's
  shape when the board server ignored it; rejected/2 answers %{ok: false, shape: shape} with
  the server's copy for a known id, or nil. A bad payload must neither raise, which would
  crash this viewer's LiveView, nor reach the board server, which every viewer reads from.
  render_hook/3 sends an event as the hook would, assert_reply/2 matches the reply, and
  BoardServer.snapshot/1 shows what landed: [] for an empty board.

      Write:          lib/easel/shapes.ex:38  (Easel.Shapes.cast_shape/3)
      Exercised by:   test/koans/09_client_to_server_test.exs:76

  API you'll use
    struct/1          struct(Vote) is an empty %Vote{}
    Map.from_struct/1  Map.from_struct(%Vote{choice: 2}) is %{choice: 2}
    cast/3            cast({%{}, %{n: :integer}}, %{"n" => "4"}, [:n]) casts n to 4
    validate_number/3  validate_number(cs, :n, greater_than_or_equal_to: 0) lets 0 through
    apply_action/2    apply_action(cs, :vote) is {:ok, data} or {:error, changeset}
    with/1            with {:error, _} <- result, do: :oops passes any other result through
    Ecto.UUID.cast/1  Ecto.UUID.cast("x") is :error; a UUID string comes back as {:ok, uuid}
    Validations.width/0, height/0  the board's 1600 and 1000
    run_op/3          run_op(socket, {:add, shape}, id) applies the op and is the reply map
    rejected/2        rejected(socket, payload) is the refusal reply map
    render_hook/3     render_hook(view, "vote", %{"choice" => 2}) sends the event, no button
    assert_reply/2    assert_reply(view, %{counted: 2}) matches the reply as a pattern
    BoardServer.snapshot/1, get_shape/2  the board's shapes; one shape by id, or nil
    Process.alive?/1  Process.alive?(view.pid) is true while the LiveView runs

  Picture: lessons/svg/09_round_trip.svg
  """
  use Koans, case: EaselWeb.ConnCase

  import Phoenix.LiveViewTest
  import Easel.BoardsFixtures

  alias Easel.Boards.BoardServer
  alias Easel.Shapes

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
  @other "7a2b3c4d-5e6f-4a7b-8c9d-0123456789ab"
  @rect %{
    "id" => @id,
    "kind" => "rect",
    "color" => "#e03131",
    "x" => 10,
    "y" => 20,
    "w" => 30,
    "h" => 40
  }

  defp open_board do
    board = board_fixture()
    {:ok, view, _html} = live(with_identity(build_conn(), "Ada"), ~p"/b/#{board.slug}")
    {board, view}
  end

  koan "Implement cast_shape/3, which Shapes.cast/1 calls once cast_kind/1 has passed the kind, so a payload becomes a plain map with atom keys and its kind, and a bad one {:error, changeset}. 1. Build the kind's empty struct and pipe it through the kind's changeset/2 with the payload. 2. apply_action/2 it. 3. On {:ok, shape}, make the struct a map and put the kind back." do
    assert Shapes.cast(@rect) ==
             {:ok, %{id: @id, kind: "rect", color: "#e03131", x: 10, y: 20, w: 30, h: 40}}

    assert {:ok, %{x: x}} = Shapes.cast(%{@rect | "x" => "5"})
    assert x == __
    assert {:error, %Ecto.Changeset{}} = Shapes.cast(%{@rect | "x" => 10.5})
    assert {:error, %Ecto.Changeset{}} = Shapes.cast(%{@rect | "kind" => "hexagon"})
    assert {:error, %Ecto.Changeset{}} = Shapes.cast([1, 2])
    assert Shapes.cast(Map.merge(@rect, %{"z" => 99, "owner" => "mallory"})) == Shapes.cast(@rect)
  end

  koan "Implement cast_move/1 and cast_id/1, the checks for shape:move and shape:delete. 1. cast_move/1: a schemaless changeset with id as Ecto.UUID and x and y as :integer, all three required, x from 0 to 1600 and y from 0 to 1000 with the edges allowed, then apply_action/2; turn {:error, _changeset} into :error. 2. cast_id/1: Ecto.UUID.cast/1 of a string id, and :error for any other payload." do
    assert Shapes.cast_move(%{"id" => @id, "x" => 1600, "y" => 1000}) ==
             {:ok, %{id: @id, x: 1600, y: 1000}}

    assert Shapes.cast_move(%{"id" => @id, "x" => 0, "y" => "7"}) == {:ok, %{id: @id, x: 0, y: 7}}
    assert Shapes.cast_move(%{"id" => @id, "x" => 1601, "y" => 0}) == :error
    assert Shapes.cast_move(%{"id" => @id, "x" => 0, "y" => 1001}) == :error
    assert Shapes.cast_move(%{"id" => @id, "x" => -1, "y" => 0}) == :error
    assert Shapes.cast_move(%{"id" => @id, "x" => 0, "y" => -1}) == :error
    assert Shapes.cast_move(%{"id" => @id, "x" => 1.5, "y" => 0}) == :error
    assert Shapes.cast_move(%{"id" => "not-a-uuid", "x" => 1, "y" => 1}) == :error
    assert Shapes.cast_move(%{"id" => @id, "x" => 1}) == :error
    assert Shapes.cast_move(%{"x" => 1, "y" => 1}) == :error
    assert Shapes.cast_move(%{"id" => @id, "y" => 1}) == :error

    assert Shapes.cast_id(%{"id" => @id}) == {:ok, @id}
    assert Shapes.cast_id(%{"id" => "not-a-uuid"}) == :error
    assert Shapes.cast_id(%{"id" => 7}) == :error
    assert Shapes.cast_id(%{}) == :error
    assert Shapes.cast_id([1, 2]) == :error
  end

  koan "Implement the shape:add clause of handle_event/3 so a valid shape lands on the board server with the reply %{ok: true}, and a payload Shapes.cast/1 refuses gets rejected/2's reply while the LiveView keeps running. 1. Case on Shapes.cast(payload). 2. On {:ok, shape}, reply with run_op/3 and the op {:add, shape}. 3. On {:error, _changeset}, reply with rejected/2." do
    {board, view} = open_board()

    render_hook(view, "shape:add", @rect)
    assert_reply view, %{ok: true}
    assert [%{id: @id, z: 0}] = BoardServer.snapshot(board.slug)

    render_hook(view, "shape:add", %{@rect | "color" => "#000000"})
    assert_reply view, %{ok: false, shape: %{id: @id, color: "#e03131"}}

    for payload <- [
          %{@rect | "id" => "not-a-uuid"},
          %{@rect | "id" => @other, "kind" => "hexagon"},
          %{@rect | "id" => @other, "x" => 1590},
          Map.delete(%{@rect | "id" => @other}, "w"),
          %{
            "id" => @other,
            "kind" => "pen",
            "color" => "#e03131",
            "x" => 0,
            "y" => 0,
            "points" => List.duplicate([1, 1], 2001)
          },
          [1, 2]
        ] do
      render_hook(view, "shape:add", payload)
      assert_reply view, %{ok: false, shape: nil}
    end

    assert Process.alive?(view.pid)
    assert length(BoardServer.snapshot(board.slug)) == 1
  end

  koan "Implement the shape:move clause the same way over Shapes.cast_move/1: {:ok, %{id: id, x: x, y: y}} runs {:move, id, x, y}, and :error replies with rejected/2. A refused move of a known shape gets the server's shape back, and a move of an unknown id is ignored with shape nil. The given shape:delete clause reads the same." do
    {board, view} = open_board()
    render_hook(view, "shape:add", @rect)
    assert_reply view, %{ok: true}

    render_hook(view, "shape:move", %{"id" => @id, "x" => 50, "y" => 60})
    assert_reply view, %{ok: true}
    render_hook(view, "shape:move", %{"id" => @id, "x" => 5000, "y" => 60})
    assert_reply view, %{ok: false, shape: %{id: @id, x: 50, y: 60}}
    render_hook(view, "shape:move", %{"id" => @other, "x" => 1, "y" => 1})
    assert_reply view, %{ok: false, shape: nil}
    render_hook(view, "shape:move", %{"x" => 1, "y" => 1})
    assert_reply view, %{ok: false, shape: nil}

    render_hook(view, "shape:delete", %{"id" => @id})
    assert_reply view, %{ok: true}
    assert BoardServer.snapshot(board.slug) == __
  end
end
