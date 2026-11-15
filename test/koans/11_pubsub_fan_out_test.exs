defmodule Koans.Ch11.PubsubFanOutTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel/boards.ex: Easel.Boards.subscribe/1, broadcast_op/2
    - lib/easel_web/live/board_live.ex: EaselWeb.BoardLive.handle_event/3, handle_info/2

  One board, many viewers. Phoenix.PubSub keeps processes on topics: subscribe/2 puts the
  caller on one, broadcast/3 sends a message to every process on it, the caller too if it
  subscribed, and broadcast_from/4 to every one but the pid it names. On one node the sends
  happen inside the call, so when it returns each subscriber has the message in its mailbox.
  A board's topic is Boards.topic(slug), "board:" and the slug. A scoreboard, for one:

      def watch(m), do: Phoenix.PubSub.subscribe(Scores.PubSub, "match:" <> m)
      def score(m, goal), do: Phoenix.PubSub.broadcast(Scores.PubSub, "match:" <> m, goal)

  The board server broadcasts each op it applies as {:board_op, event, payload}, and every
  BoardLive pushes it to its browser (chapter 10), the sender's own included. join/2
  subscribes before it takes the snapshot. An op applied before the snapshot is in it; one
  applied after the subscribe arrives as a message; one in between is in both, a harmless
  repeat. The other order loses an op that lands between the snapshot and the subscribe.

  Cursors skip the board server and are never stored. The cursor:move handler puts x and y on
  me (tab, name and colour) and sends {:cursor, cursor} with broadcast_from/4 from self(), so
  every other BoardLive pushes it as cursor:moved and the sender's browser, which knows where
  its own pointer is, gets nothing.

  Across nodes, PubSub's default adapter sends each broadcast once to every other node, which
  hands it to its own subscribers, so a viewer on any node hears the board. But the Registry is
  per node: a cluster needs a cluster-wide name (:global, or Horde) to keep one board server.

      Write:          lib/easel/boards.ex:56  (Easel.Boards.subscribe/1)
      Exercised by:   test/koans/11_pubsub_fan_out_test.exs:93

  API you'll use
    Phoenix.PubSub.subscribe/2  Phoenix.PubSub.subscribe(Scores.PubSub, "match:7") is :ok
    Phoenix.PubSub.broadcast/3  Phoenix.PubSub.broadcast(Scores.PubSub, "match:7", :goal) is :ok
    Phoenix.PubSub.broadcast_from/4  the same with a pid first, which it skips: self() here
    Boards.topic/1    Boards.topic("abc") is "board:abc"
    Map.merge/2       Map.merge(%{a: 1}, %{b: 2}) is %{a: 1, b: 2}
    push_event/3      chapter 10
    assert_received/1, refute_received/1  match a message already in the mailbox, no waiting
    render_hook/3, assert_reply/2  chapter 09
    render/1          render(view) waits until the view has handled its mailbox, so its pushes
                      are in yours
    assert_push_event/3, refute_push_event/4  refute_push_event(view, "tick", %{}, 0) checks no
                      push came, without waiting
    board_props/1     the Board's whole props; a snapshot of an empty board is []
    broadcast_during_snapshot/3  given in this file: holds the board server, broadcasts once a
                      snapshot call reaches it, then lets it answer

  Picture: lessons/svg/11_fan_out.svg
  """
  use Koans, case: EaselWeb.ConnCase

  import Phoenix.LiveViewTest
  import Easel.BoardsFixtures

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

  defp open(board, name) do
    {:ok, view, _html} = live(with_identity(build_conn(), name), ~p"/b/#{board.slug}")
    view
  end

  # A receive trace tells the barrier when the snapshot call reaches the suspended server.
  defp broadcast_during_snapshot(server, slug, message) do
    barrier =
      spawn_link(fn ->
        receive do
          {:trace, ^server, :receive, {:"$gen_call", _from, :snapshot}} -> :ok
        end

        :ok = Boards.broadcast_op(slug, message)
        :sys.resume(server)
      end)

    :ok = :sys.suspend(server)
    1 = :erlang.trace(server, true, [:receive, {:tracer, barrier}])
  end

  koan "Implement subscribe/1 and broadcast_op/2, so a process that subscribes to a board hears every message broadcast on that board and nothing from another. 1. subscribe/1 puts the caller on the slug's topic in Easel.PubSub. 2. broadcast_op/2 sends the message to every subscriber of that topic." do
    :ok = Boards.subscribe("north")
    :ok = Boards.broadcast_op("north", {:board_op, "shape:deleted", %{id: @id}})
    :ok = Boards.broadcast_op("south", {:board_op, "shape:deleted", %{id: "elsewhere"}})

    assert_received {:board_op, "shape:deleted", %{id: @id}}
    refute_received {:board_op, _event, %{id: "elsewhere"}}
  end

  koan "An add in Ada's view reaches Lin's view as a push, and Ada's own: the board server broadcasts each op it applies, and every BoardLive that join/2 subscribed pushes it on." do
    board = board_fixture()
    ada = open(board, "Ada")
    lin = open(board, "Lin")

    render_hook(ada, "shape:add", @rect)
    assert_reply ada, %{ok: true}
    _ = render(lin)
    _ = render(ada)

    assert_push_event lin, "shape:added", %{id: @id, kind: "rect", x: 10, y: 20, w: 30, h: 40}
    assert_push_event ada, "shape:added", %{id: @id}
  end

  koan "join/2 subscribes before it takes the snapshot, so an op broadcast while the snapshot is on its way still reaches the browser, as a push the snapshot never saw." do
    board = board_fixture()
    {:ok, server} = BoardServer.ensure_started(board.slug)
    shape = %{id: @id, kind: "rect", color: "#e03131", x: 1, y: 1, w: 5, h: 5, z: 0}
    broadcast_during_snapshot(server, board.slug, {:board_op, "shape:added", shape})

    view = open(board, "Ada")
    _ = render(view)

    assert_push_event view, "shape:added", %{id: @id}
    assert board_props(view)["shapes"] == __
  end

  koan "Implement the cursor:move handler and the {:cursor, cursor} clause, so Ada's pointer reaches Lin's view as cursor:moved and never comes back to Ada. 1. Put x and y on me, tab included. 2. broadcast_from/4 {:cursor, cursor} on the board's topic, skipping self(). 3. In handle_info/2, push the cursor as cursor:moved." do
    board = board_fixture()
    ada = open(board, "Ada")
    lin = open(board, "Lin")
    tab = board_props(ada)["me"]["tab"]

    render_hook(ada, "cursor:move", %{"x" => 10, "y" => 20})
    _ = render(lin)
    _ = render(ada)

    assert_push_event lin, "cursor:moved", %{tab: ^tab, name: "Ada", color: "#e03131", x: 10, y: 20}
    refute_push_event ada, "cursor:moved", %{}, 0
  end
end
