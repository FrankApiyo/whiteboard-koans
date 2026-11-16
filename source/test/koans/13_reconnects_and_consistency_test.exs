defmodule Koans.Ch13.ReconnectsAndConsistencyTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel/boards/board_server.ex: Easel.Boards.BoardServer.announce_restart/1
    - lib/easel_web/live/board_live.ex: EaselWeb.BoardLive.handle_info/2

  Every viewer comes back to the board server's state. A LiveView lives as long as its socket:
  when the connection drops the process ends, and the reconnect mounts a new one. That runs
  join/2 again in its given order (tab id, ensure_started, subscribe, track_presence, snapshot,
  sync_id), so the new process has a new tab, the board as the server holds it now, and a fresh
  sync_id, on which the browser's surviving component resyncs (the TypeScript koans).

  The board server can restart under its viewers instead: it crashes, and the DynamicSupervisor
  starts it again from the database, or it stopped when idle, and the next call started it
  again (chapter 08's call/2); every start announces. A crash still saves in terminate/2; a :kill
  skips it and loses the ops in the save window. init/1 calls announce_restart/1, which broadcasts
  :board_restarted on the board's topic, and each BoardLive answers it as a reconnect would: a
  fresh snapshot and a new sync_id. live_svelte then sends only the props that changed, which it
  can tell only with socket={@socket}. A shop's price list does the same when its prices reload:

      def handle_info(:prices_reloaded, socket),
        do: {:noreply, assign(socket, prices: Prices.all(), version: Prices.version())}

  One race is left. ensure_started/1 looks a board up before it asks the supervisor, so only a
  caller that has just seen the board die can race the DynamicSupervisor's restart of it;
  closing that too would take restart: :temporary and call/2's retry alone.

      Write:          lib/easel/boards/board_server.ex:34  (Easel.Boards.BoardServer.announce_restart/1)
      Exercised by:   test/koans/13_reconnects_and_consistency_test.exs:66

  API you'll use
    Boards.broadcast_op/2   chapter 11; any message goes, :board_restarted too
    BoardServer.snapshot/1  chapter 08; apply_op/2 applies an op as another viewer's would
    BoardServer.get_shape/2  chapter 08: the shape with that id, or nil
    assign/2          assign(socket, prices: [], version: 2) sets both
    sync_id/0         given in BoardLive: a fresh positive integer on each call
    get_svelte/1      get_svelte(view).props is what live_svelte last sent, after the first
                      render only the keys that changed
    board_props/1     the Board's whole props
    GenServer.stop/1  GenServer.stop(view.pid) ends a view, as a dropped socket does
    DynamicSupervisor.start_child/2  chapter 08; save_after: 60_000 keeps the save window open
    Process.exit/2    Process.exit(pid, :kill) kills it outright
    assert_receive/1  waits for a message: subscribe first, then wait for the real broadcast

  Picture: lessons/svg/13_resync.svg
  """
  use Koans, case: EaselWeb.ConnCase

  import Phoenix.LiveViewTest
  import LiveSvelte.Test
  import Easel.BoardsFixtures

  alias Easel.Boards
  alias Easel.Boards.BoardServer

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
  @other "0b8c3a52-7a8f-4c1e-9d7e-1f0a5f3b2c01"
  @shape %{id: @id, kind: "rect", color: "#e03131", x: 10, y: 20, w: 30, h: 40}
  @rect %{"id" => @id, "kind" => "rect", "color" => "#e03131", "x" => 10, "y" => 20, "w" => 30, "h" => 40}

  defp open(board, name) do
    {:ok, view, _html} = live(with_identity(build_conn(), name), ~p"/b/#{board.slug}")
    view
  end

  koan "Implement announce_restart/1, which init/1 calls once a board's shapes are loaded: broadcast :board_restarted on that board's topic, so its viewers, and no other board's, hear that its server started." do
    board = board_fixture()
    :ok = Boards.subscribe(board.slug)

    assert BoardServer.announce_restart(board.slug) == :ok
    assert_receive :board_restarted
    assert BoardServer.announce_restart(board_fixture().slug) == :ok
    refute_receive :board_restarted, 0

    {:ok, _pid} = BoardServer.ensure_started(board.slug)
    assert_receive :board_restarted
  end

  koan "Implement the :board_restarted clause of handle_info/2, so a view resyncs as a reconnect would. 1. Take a fresh snapshot of the board. 2. Assign it as the shapes, with a new sync_id. live_svelte then sends just shapes and sync_id, never the unchanged me." do
    board = board_fixture()
    view = open(board, "Ada")
    sync_id = board_props(view)["sync_id"]
    :ok = BoardServer.apply_op(board.slug, {:add, @shape})
    assert board_props(view)["shapes"] == []

    send(view.pid, :board_restarted)
    props = board_props(view)
    assert [%{"id" => @id}] = props["shapes"]
    refute props["sync_id"] == sync_id
    assert get_svelte(view).props |> Map.keys() |> Enum.sort() == ["shapes", "sync_id"]
  end

  koan "A reconnect is a new LiveView process that runs mount again: the same person comes back under a new tab and a new sync_id, with the shapes as the board server holds them now, an add made while they were away included." do
    board = board_fixture()
    first = open(board, "Ada")
    gone = board_props(first)
    GenServer.stop(first.pid)
    :ok = BoardServer.apply_op(board.slug, {:add, @shape})

    back = board_props(open(board, "Ada"))
    refute back["me"]["tab"] == gone["me"]["tab"]
    refute back["sync_id"] == gone["sync_id"]
    assert length(back["shapes"]) == _a(1)
  end

  koan "A killed board server comes back from the database and announces it, so every view resyncs on a new sync_id to what was saved: an add still in the save window is gone." do
    board = board_fixture()
    shape_fixture(board, z: 0, client_id: @other)

    {:ok, server} =
      DynamicSupervisor.start_child(
        Easel.Boards.BoardSupervisor,
        {BoardServer, slug: board.slug, save_after: 60_000}
      )

    view = open(board, "Ada")
    sync_id = board_props(view)["sync_id"]
    render_hook(view, "shape:add", @rect)
    assert_reply view, %{ok: true}
    :ok = Boards.subscribe(board.slug)

    Process.exit(server, :kill)
    assert_receive :board_restarted
    # The new server broadcasts this op after :board_restarted, so the view handles them in order.
    :ok = BoardServer.apply_op(board.slug, {:delete, @other})
    assert_push_event view, "shape:deleted", %{id: @other}

    refute board_props(view)["sync_id"] == sync_id
    assert BoardServer.get_shape(board.slug, @id) == _a(nil)
  end
end
