defmodule Koans.Ch10.ServerToClientTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel_web/live/board_live.ex: EaselWeb.BoardLive.handle_info/2

  The server pushes each change to every browser on the board. Once the board server applies an
  op it broadcasts {:board_op, event, payload} on the board's topic; every LiveView on the board
  subscribes in join/2 (chapter 11) and gets it in handle_info/2, the sender's own included.
  push_event/3 passes it on: it queues an event on the socket, and LiveView sends it with the
  next diff, where the browser dispatches it after patching the page. The payload must be a
  map. It reaches the browser as JSON, so the Svelte side guards it, and the sender's browser
  takes its own op back as a harmless repeat (this chapter's TypeScript koans).

  LiveViewTest runs no JavaScript, so assert_push_event/3 reads the pushes instead, matching
  the map as pushed, atom keys and all. A koan can stand in for the board server by sending
  the message straight to view.pid, with no subscription needed. A clock, for one:

      def handle_info({:tick, now}, socket) do
        {:noreply, push_event(socket, "clock:tick", %{at: now})}
      end

  Props and events split the work. live_svelte sends a prop again only when it changed, and
  BoardLive changes the shapes assign only on a resync (chapter 13). A push changes the
  browser's copy and no assign, so after any number of pushes board_props(view) still holds
  the snapshot from the connected mount: one shape saved before the join stays 1 shape.

      Write:          lib/easel_web/live/board_live.ex:87  (EaselWeb.BoardLive.handle_info/2)
      Exercised by:   test/koans/10_server_to_client_test.exs:47

  API you'll use
    push_event/3      push_event(socket, "clock:tick", %{at: 1}) is the socket with a push queued
    handle_info/2     answers {:noreply, socket}
    send/2            send(view.pid, {:tick, 1}) puts a message in the LiveView's mailbox
    assert_push_event/3  assert_push_event(view, "clock:tick", %{at: 1}) matches one push
    board_props/1     board_props(view) is the Board's whole props, from the view's assigns
    shape_fixture/2   shape_fixture(board, z: 0) saves one shape before the view opens

  Picture: lessons/svg/10_push_and_listen.svg
  """
  use Koans, case: EaselWeb.ConnCase

  import Phoenix.LiveViewTest
  import Easel.BoardsFixtures

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"

  koan "Implement the {:board_op, event, payload} clause of handle_info/2 so each op the board server broadcasts goes to this view's browser as a push with the same event and payload." do
    board = board_fixture()
    {:ok, view, _html} = live(with_identity(build_conn(), "Ada"), ~p"/b/#{board.slug}")

    send(view.pid, {:board_op, "shape:moved", %{id: @id, x: 50, y: 60}})
    assert_push_event view, "shape:moved", %{id: @id, x: 50, y: 60}
    send(view.pid, {:board_op, "shape:deleted", %{id: @id}})
    assert_push_event view, "shape:deleted", %{id: @id}
  end

  koan "A push leaves the props alone: the browser applies it to its own copy, and the shapes prop keeps the snapshot from the connected mount until a resync." do
    board = board_fixture()
    shape_fixture(board, z: 0)
    {:ok, view, _html} = live(with_identity(build_conn(), "Ada"), ~p"/b/#{board.slug}")
    added = %{id: @id, kind: "rect", color: "#e03131", x: 10, y: 20, w: 30, h: 40, z: 1}

    send(view.pid, {:board_op, "shape:added", added})
    assert_push_event view, "shape:added", %{id: @id, z: 1}
    assert length(board_props(view)["shapes"]) == _a(1)
  end
end
