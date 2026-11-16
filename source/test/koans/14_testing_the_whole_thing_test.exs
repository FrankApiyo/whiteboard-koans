defmodule Koans.Ch14.TestingTheWholeThingTest do
  @moduledoc ~S"""
  Files this chapter touches
    - test/support/board_helpers.ex: EaselWeb.BoardHelpers.open_board/2, add_shape/2

  Each piece is tested at its own height. test/easel/boards/board_server_test.exs drives the board
  server with no LiveView; test/easel_web/live/board_live_test.exs drives BoardLive as a browser
  would, with no browser: render_hook/3 sends an event, assert_reply/2 reads the answer,
  assert_push_event/3 a push, board_props/1 the props. Once filled, MIX_TEST_PARTITION=app mix
  test runs it on your code (KOANS_LIB=solutions/lib on the reference); exported, mix test.

  A helper keeps a test to its point. open_board/2 does chapter 06's two renders in two steps:
  get/2 asks for the page, a static render, and live/1 connects that conn, which mounts again
  with a socket. add_shape/2 sends shape:add as Board does, a whole rect under whatever the test
  gives, its own id included, and asserts the reply was %{ok: true}, so a refused shape fails at
  the helper. A helper that asserts imports ExUnit.Assertions. A chat app's helper:

      def post(view, text) do
        render_hook(view, "message:post", %{"text" => text})
        assert_reply(view, %{sent: true})
      end

  board_props/1 is a given helper, not LiveView API: it reads the view's assigns through
  :sys.get_state(view.pid), LiveView's internal state, because get_svelte(view) after the join
  shows only what live_svelte last sent. Where a test can send a timer's message itself it
  needn't wait for the timer, and :sys.get_state(pid) answers only once pid has handled every
  message this process sent it first. The Playwright suite runs the solved app with MIX_ENV=e2e:
  config/e2e.exs gives it port 4100, a database under tmp/e2e, and board timers of save_after:
  200, idle_after: 2_000, so a test can wait for an idle board to stop.

      Write:          test/support/board_helpers.ex:24  (EaselWeb.BoardHelpers.open_board/2)
      Exercised by:   test/koans/14_testing_the_whole_thing_test.exs:63

  API you'll use
    get/2, live/1     get(conn, "/posts/1") renders the page; live(conn) connects it, {:ok, view, html}
    render_hook/3     chapter 09; assert_reply/2 matches the reply, failing with an
                      ExUnit.AssertionError when none matches
    Ecto.UUID.generate/0  a fresh random UUID string
    Map.put/3         Map.put(%{a: 1}, :b, 2) is %{a: 1, b: 2}; Map.merge/2 as in chapter 11
    start_supervised!/1  starts a child under the test's supervisor, stopped when the test ends
    :sys.get_state/1  a GenServer's state; the board server's dirty? is true while a save waits
    assert_push_event/3  chapter 10; a push never changes the props
    get_svelte/1      LiveSvelte.Test: right after the join, all four props
    Config.Reader.read!/1  Config.Reader.read!("config/dev.exs") is that file's config as a
                      keyword list, app by app, without loading it
    board_props/1     the Board's whole props

  Picture: lessons/svg/14_test_layers.svg
  """
  use Koans, case: EaselWeb.ConnCase

  import Phoenix.LiveViewTest
  import LiveSvelte.Test
  import Easel.BoardsFixtures
  import EaselWeb.BoardHelpers

  alias Easel.Boards
  alias Easel.Boards.BoardServer

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
  @shape %{id: @id, kind: "rect", color: "#e03131", x: 10, y: 20, w: 30, h: 40}

  koan "Implement open_board/2, a connected view of the board for a named viewer. The given line asks for the page as a static render; connect that conn with live/1, which mounts again with a socket, and answer the view." do
    board = board_fixture()
    view = open_board(board, "Ada")

    me = board_props(view)["me"]
    assert me["name"] == "Ada"
    assert is_binary(me["tab"])
    assert [{_pid, _}] = Registry.lookup(Easel.Boards.Registry, board.slug)
  end

  koan "Implement add_shape/2, which adds a shape as Board does and insists the server took it. 1. Lay the attrs over a whole rect with a fresh Ecto.UUID as its id: kind \"rect\", colour \"#e03131\", x 10, y 20, w 30, h 40; anything in the attrs wins, an id too. 2. Send it as shape:add. 3. Assert the reply is %{ok: true}. 4. Answer the shape sent." do
    board = board_fixture()
    view = open_board(board, "Ada")

    shape = add_shape(view, %{"x" => 50})
    other = add_shape(view, %{"kind" => "ellipse"})
    assert add_shape(view, %{"id" => @id})["id"] == @id
    assert %{id: @id} = BoardServer.get_shape(board.slug, @id)

    assert Map.delete(shape, "id") == %{
             "kind" => "rect",
             "color" => "#e03131",
             "x" => 50,
             "y" => 20,
             "w" => 30,
             "h" => 40
           }

    assert {:ok, _} = Ecto.UUID.cast(shape["id"])
    refute shape["id"] == other["id"]
    assert %{x: 50, kind: "rect"} = BoardServer.get_shape(board.slug, shape["id"])
    assert %{kind: "ellipse"} = BoardServer.get_shape(board.slug, other["id"])
    assert_raise ExUnit.AssertionError, fn -> add_shape(view, %{"x" => 5000}) end
  end

  koan "A board server test that isn't about the timer needn't wait for it: the test sends :save itself, and :sys.get_state/1 answers only once the server has handled it." do
    board = board_fixture()
    pid = start_supervised!({BoardServer, slug: board.slug, save_after: 60_000})

    :ok = BoardServer.apply_op(board.slug, {:add, @shape})
    assert :sys.get_state(pid).dirty? == _a(true)
    assert Boards.load_shapes(board) == []

    send(pid, :save)
    assert :sys.get_state(pid).dirty? == _a(false)
    assert [%{id: @id}] = Boards.load_shapes(board)
  end

  koan "A LiveView test reads a view three ways: assert_push_event/3 for what it pushed, board_props/1 for the whole props it holds, which a push leaves alone, and get_svelte/1 for what live_svelte last sent, all four props right after the join." do
    board = board_fixture()
    ada = open_board(board, "Ada")
    lin = open_board(board, "Lin")

    %{"id" => id} = add_shape(ada, %{})
    assert_push_event lin, "shape:added", %{id: ^id}

    assert board_props(lin)["shapes"] == _a([])
    assert get_svelte(lin).props |> Map.keys() |> Enum.sort() == _a(["me", "people", "shapes", "sync_id"])
  end

  koan "The Playwright suite runs its own server, with MIX_ENV=e2e, from config/e2e.exs: port 4100, a database under tmp/e2e, and board timers short enough that a test can wait for an idle board to stop and come back from the database." do
    config = Config.Reader.read!("config/e2e.exs")

    assert config[:easel][EaselWeb.Endpoint][:http][:port] == _a(4100)
    assert config[:easel][:board_server] == _a([save_after: 200, idle_after: 2_000])
    assert config[:easel][Easel.Repo][:database] |> Path.dirname() |> Path.basename() == "e2e"
  end
end
