defmodule EaselWeb.BoardLiveTest do
  use EaselWeb.ConnCase

  import Phoenix.LiveViewTest
  import LiveSvelte.Test
  import Easel.BoardsFixtures
  import EaselWeb.BoardHelpers

  alias Easel.Boards
  alias Easel.Boards.BoardServer

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
  @rect %{
    "id" => @id,
    "kind" => "rect",
    "color" => "#e03131",
    "x" => 10,
    "y" => 20,
    "w" => 30,
    "h" => 40
  }

  setup do
    %{board: board_fixture()}
  end

  defp props(view), do: board_props(view)

  defp server(board) do
    [{pid, _}] = Registry.lookup(Easel.Boards.Registry, board.slug)
    pid
  end

  defp eventually(check, tries \\ 50) do
    cond do
      check.() ->
        true

      tries == 0 ->
        flunk("condition never became true")

      true ->
        Process.sleep(10)
        eventually(check, tries - 1)
    end
  end

  describe "static render" do
    test "renders the Board component without starting a board server", %{
      conn: conn,
      board: board
    } do
      html = conn |> with_identity("Ada") |> get(~p"/b/#{board.slug}") |> html_response(200)

      assert %{name: "Board", props: %{"shapes" => [], "people" => []}} = get_svelte(html)
      assert Registry.lookup(Easel.Boards.Registry, board.slug) == []
    end

    test "an unknown slug is not found", %{conn: conn} do
      assert_error_sent 404, fn -> conn |> with_identity("Ada") |> get(~p"/b/missing") end
    end

    test "without a name the visitor is sent to the name form", %{conn: conn, board: board} do
      assert {:error, {:redirect, %{to: "/name"}}} = live(conn, ~p"/b/#{board.slug}")
    end
  end

  describe "connected mount" do
    test "props carry the saved shapes, a sync id, me and the people", %{board: board} do
      shape = shape_fixture(board)

      props = board |> open_board("Ada") |> props()

      assert [%{"id" => id, "kind" => "rect", "x" => 10}] = props["shapes"]
      assert id == shape.client_id
      assert is_integer(props["sync_id"]) and props["sync_id"] > 0
      assert %{"name" => "Ada", "color" => "#e03131", "tab" => tab} = props["me"]
      assert is_binary(tab)
      assert props["people"] == [props["me"]]
    end

    test "the first viewer's join does not resync", %{board: board} do
      view = open_board(board, "Ada")

      sent = get_svelte(view).props

      assert Map.has_key?(sent, "shapes")
      assert sent["sync_id"] == board_props(view)["sync_id"]
    end

    test "subscribe_before_snapshot", %{board: board} do
      {:ok, server} = BoardServer.ensure_started(board.slug)
      shape = %{id: @id, kind: "rect", color: "#e03131", x: 1, y: 1, w: 5, h: 5, z: 0}

      # Broadcast when the snapshot call reaches the suspended server (seen through a
      # receive trace): only a LiveView that subscribed before the snapshot gets the op.
      barrier =
        spawn_link(fn ->
          receive do
            {:trace, ^server, :receive, {:"$gen_call", _from, :snapshot}} -> :ok
          end

          Boards.broadcast_op(board.slug, {:board_op, "shape:added", shape})
          :sys.resume(server)
        end)

      :ok = :sys.suspend(server)
      1 = :erlang.trace(server, true, [:receive, {:tracer, barrier}])

      view = open_board(board, "Ada")
      _ = render(view)

      assert_push_event view, "shape:added", %{id: @id}
    end
  end

  describe "shape events" do
    test "an add replies ok and reaches every viewer, the sender included", %{
      board: board
    } do
      ada = open_board(board, "Ada")
      bob = open_board(board, "Bob")

      add_shape(bob, @rect)

      assert_push_event ada, "shape:added", %{id: @id, x: 10, z: 0}
      assert_push_event bob, "shape:added", %{id: @id, x: 10, z: 0}
    end

    test "moves and deletes reach the other viewers", %{board: board} do
      ada = open_board(board, "Ada")
      bob = open_board(board, "Bob")
      add_shape(ada, @rect)

      render_hook(ada, "shape:move", %{"id" => @id, "x" => 50, "y" => 60})
      assert_reply ada, %{ok: true}
      assert_push_event bob, "shape:moved", %{id: @id, x: 50, y: 60}

      render_hook(ada, "shape:delete", %{"id" => @id})
      assert_reply ada, %{ok: true}
      assert_push_event bob, "shape:deleted", %{id: @id}
    end

    test "a rejected change to a known shape replies with the server's shape", %{
      board: board
    } do
      view = open_board(board, "Ada")
      add_shape(view, @rect)

      render_hook(view, "shape:move", %{"id" => @id, "x" => 5000, "y" => 60})

      assert_reply view, %{ok: false, shape: %{id: @id, x: 10, y: 20}}
    end

    test "hostile_payloads_are_rejected_and_nothing_crashes", %{board: board} do
      view = open_board(board, "Ada")
      unknown = Ecto.UUID.generate()
      pen = %{@rect | "kind" => "pen"} |> Map.drop(["w", "h"])

      hostile = [
        {"shape:add", %{@rect | "id" => "not-a-uuid"}},
        {"shape:add", %{@rect | "kind" => "hexagon"}},
        {"shape:add", %{@rect | "x" => 10.5}},
        {"shape:add", %{@rect | "x" => 5000}},
        {"shape:add", %{@rect | "color" => "#000000"}},
        {"shape:add", Map.put(pen, "points", List.duplicate([1, 1], 2001))},
        {"shape:add", Map.put(pen, "points", [[1, nil]])},
        {"shape:add", Map.put(pen, "points", [[nil, 1]])},
        {"shape:add", Map.delete(@rect, "w")},
        {"shape:move", %{"id" => unknown, "x" => 1, "y" => 1}},
        {"shape:move", %{"id" => @id, "x" => 1.5, "y" => 1}},
        {"shape:move", %{"id" => "not-a-uuid", "x" => 1, "y" => 1}},
        {"shape:delete", %{"id" => unknown}},
        {"shape:delete", %{"id" => "not-a-uuid"}},
        {"shape:delete", %{}},
        {"shape:add", [1, 2]},
        {"shape:move", [1, 2]},
        {"shape:delete", [1, 2]}
      ]

      for {event, payload} <- hostile do
        render_hook(view, event, payload)
        assert_reply view, %{ok: false, shape: nil}
      end

      assert Process.alive?(view.pid)
      assert Process.alive?(server(board))
      assert BoardServer.snapshot(board.slug) == []
    end

    test "props change only on a resync", %{board: board} do
      ada = open_board(board, "Ada")
      bob = open_board(board, "Bob")
      sync_id = props(ada)["sync_id"]

      add_shape(bob, @rect)
      assert_push_event ada, "shape:added", %{id: @id}
      assert props(ada)["shapes"] == []
      assert props(ada)["sync_id"] == sync_id

      Boards.broadcast_op(board.slug, :board_restarted)

      assert [%{"id" => @id}] = props(ada)["shapes"]
      refute props(ada)["sync_id"] == sync_id
    end

    test "a restarted board server gives the view a new sync id", %{board: board} do
      view = open_board(board, "Ada")
      sync_id = props(view)["sync_id"]

      Process.exit(server(board), :kill)

      eventually(fn -> props(view)["sync_id"] != sync_id end)
    end
  end

  describe "cursors and presence" do
    test "a cursor reaches the other viewers but not the sender", %{board: board} do
      ada = open_board(board, "Ada")
      bob = open_board(board, "Bob")
      tab = props(ada)["me"]["tab"]

      render_hook(ada, "cursor:move", %{"x" => 10, "y" => 20})

      assert_push_event bob, "cursor:moved", %{tab: ^tab, name: "Ada", x: 10, y: 20}
      refute_push_event ada, "cursor:moved", %{}
    end

    test "a cursor with bad coordinates is dropped", %{board: board} do
      ada = open_board(board, "Ada")
      bob = open_board(board, "Bob")

      render_hook(ada, "cursor:move", %{"x" => "10", "y" => 20})

      refute_push_event bob, "cursor:moved", %{}
      assert Process.alive?(ada.pid)
    end

    test "a presence change sends people but not the shapes", %{board: board} do
      shape_fixture(board)
      ada = open_board(board, "Ada")
      assert [_shape] = props(ada)["shapes"]

      open_board(board, "Bob")

      eventually(fn -> length(props(ada)["people"]) == 2 end)
      sent = get_svelte(ada).props
      assert Map.has_key?(sent, "people")
      refute Map.has_key?(sent, "shapes")
    end

    test "people lists every tab, and a tab that leaves drops out", %{board: board} do
      names = fn view -> view |> props() |> Map.fetch!("people") |> Enum.map(& &1["name"]) end
      ada = open_board(board, "Ada")
      bob = open_board(board, "Bob")

      assert Enum.sort(names.(bob)) == ["Ada", "Bob"]
      eventually(fn -> Enum.sort(names.(ada)) == ["Ada", "Bob"] end)

      GenServer.stop(bob.pid)

      eventually(fn -> names.(ada) == ["Ada"] end)
    end
  end
end
