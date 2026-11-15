defmodule Koans.Ch08.TheBoardServerTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel/boards/ops.ex: Easel.Boards.Ops.apply/2
    - lib/easel/boards/board_server.ex: Easel.Boards.BoardServer.via/1, ensure_started/1,
      init/1, reset_idle_timer/1, call/2, handle_call/3, open_save_window/1, handle_info/2

  One process per board holds its shapes. BoardServer is a GenServer named with a via tuple,
  {:via, Registry, {registry, key}}, so callers reach it by slug alone. Its given supervisor,
  Easel.Boards.BoardSupervisor, sets max_restarts: 100 in max_seconds: 5 (the default is 3),
  so a few crashes on different boards don't stop every board. use GenServer, restart:
  :transient restarts a board after a crash, not after a :normal stop. init/1 runs inside
  start_child, so starts queue one by one; a slow load would move to handle_continue/2. A crash
  in init/1 repeats at once and uses up any limit, so a missing board's init/1 returns :ignore,
  which ensure_started/1 turns into {:error, :not_found}. A callback is a plain function; a tally:

      def handle_call({:bump, key}, _from, counts) do
        counts = Map.update(counts, key, 1, &(&1 + 1))
        {:reply, Map.fetch!(counts, key), counts}
      end

  Ops apply by id. A known id re-added replaces its shape and keeps its z; a new one takes
  next_z. A move or delete of an unknown id is {:ignored, state}, so no move revives a deleted
  shape. Saves are batched: the first unsaved op opens a fixed window, and the :save at its end
  writes every shape. Each op restarts the idle timer with a fresh ref. Process.cancel_timer/1
  can't take back an {:idle, ref} already in the mailbox, so only the current ref may stop the
  board. Trapping exits makes terminate/2 save on a shutdown, and an exception saves there too;
  only :kill skips terminate/2 and loses the open window. call/2 tries again once when the board
  has stopped, and a real start error on that second try crashes loudly.

      Write:          lib/easel/boards/ops.ex:7  (Easel.Boards.Ops.apply/2)
      Exercised by:   test/koans/08_the_board_server_test.exs:98

  API you'll use
    Map.fetch/2       Map.fetch(%{a: 1}, :a) is {:ok, 1}; Map.fetch(%{a: 1}, :b) is :error
    Map.put/3, Map.delete/2  Map.put(%{a: 1}, :a, 2) is %{a: 2}; Map.delete(%{a: 1}, :a) is %{}
    Map.values/1, Enum.sort_by/2  Enum.sort_by(["bb", "a"], &String.length/1) is ["a", "bb"]
    Ops.apply/2       is {:applied, state, event, payload} or {:ignored, state}
    DynamicSupervisor.start_child/2  start_child(sup, {Tally, name: "t"}) is {:ok, pid},
      {:error, {:already_started, pid}} for a taken name, or :ignore when init/1 says so
    GenServer.call/2  GenServer.call(name, :ping) exits {:noproc, _} when no process has name
    GenServer.whereis/1  GenServer.whereis({:via, Registry, {Reg, "t"}}) is the pid or nil
    Process.flag/2    Process.flag(:priority, :high) is the old value; :trap_exit turns exit
      signals into messages
    Process.send_after/3  Process.send_after(self(), :tick, 1_000) is the timer's reference
    make_ref/0        make_ref() is a reference no other call returns
    init/1, handle_call/3, handle_info/2  answer {:ok, state} or :ignore; {:reply, reply, state};
      {:noreply, state} or {:stop, :normal, state}
    :sys.get_state/1, :sys.suspend/1, :sys.resume/1  a server's state, for a look from a test;
      pause its mailbox, and carry on
    start_supervised!/1  start_supervised!({Tally, name: "t"}) is a pid the test stops at its end
    catch_exit/1      catch_exit(GenServer.call(pid, :bad)) is the exit reason, caught
    try/catch :exit   try do GenServer.call(n, :ping) catch :exit, {:timeout, _} -> :slow end;
      a def body can take catch directly, with no try
    board_props/1     board_props(view) is the view's whole props map, a given ConnCase helper

  Picture: lessons/svg/08_board_server.svg
  """
  use Koans, case: EaselWeb.ConnCase

  import Phoenix.LiveViewTest
  import Easel.BoardsFixtures

  alias Easel.Boards
  alias Easel.Boards.{BoardServer, Ops}

  @a "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
  @b "7a2b3c4d-5e6f-4a7b-8c9d-0123456789ab"

  defp rect(id), do: %{id: id, kind: "rect", color: "#e03131", x: 10, y: 20, w: 30, h: 40}

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

  defp queued(pid), do: pid |> Process.info(:message_queue_len) |> elem(1)

  defp restarted?(slug, old),
    do: match?([{new, nil}] when new != old, Registry.lookup(Easel.Boards.Registry, slug))

  koan "use GenServer gives BoardServer a child_spec/1 that a supervisor starts with start_link/1, and that restarts it after a crash but not after a :normal stop." do
    spec = BoardServer.child_spec(slug: "plan")

    assert spec.start == {BoardServer, :start_link, [[slug: "plan"]]}
    assert spec.restart == _a(:transient)
  end

  koan "Implement the :add clause of Ops.apply/2 so a new shape takes next_z and bumps it, while a known id added again replaces its shape and keeps its z. 1. Look the id up in the shapes with Map.fetch/2. 2. Stamp the z on the shape with Map.put/3 and store it under its id. 3. Answer {:applied, state, \"shape:added\", stamped_shape}." do
    empty = %{shapes: %{}, next_z: 0}

    assert {:applied, one, "shape:added", added} = Ops.apply(empty, {:add, rect(@a)})
    assert {added.z, one.next_z} == {0, 1}
    assert {:applied, two, _, _} = Ops.apply(one, {:add, rect(@b)})

    again = %{rect(@a) | color: "#2f9e44"}
    assert {:applied, three, "shape:added", readded} = Ops.apply(two, {:add, again})
    assert {readded.z, readded.color, three.next_z} == {0, "#2f9e44", 2}
    assert {map_size(three.shapes), three.shapes[@a].color} == {2, "#2f9e44"}
  end

  koan "Implement the :move and :delete clauses of Ops.apply/2 so they change a known shape and ignore an unknown id, which keeps a late move from bringing a deleted shape back. 1. Move: set x and y, and answer {:applied, state, \"shape:moved\", %{id: id, x: x, y: y}}. 2. Delete: drop the shape, and answer \"shape:deleted\" with %{id: id}. 3. Unknown id: answer {:ignored, state}." do
    {:applied, state, _, _} = Ops.apply(%{shapes: %{}, next_z: 0}, {:add, rect(@a)})

    assert {:applied, moved, "shape:moved", payload} = Ops.apply(state, {:move, @a, 70, 80})
    assert payload == %{id: @a, x: 70, y: 80}
    assert Map.take(moved.shapes[@a], [:x, :y, :w]) == %{x: 70, y: 80, w: 30}

    assert {:applied, gone, "shape:deleted", payload} = Ops.apply(moved, {:delete, @a})
    assert {payload, gone.shapes} == {%{id: @a}, %{}}
    assert Ops.apply(gone, {:move, @a, 1, 1}) == {:ignored, gone}
    assert Ops.apply(gone, {:delete, @a}) == {:ignored, gone}
  end

  koan "init/1 is a plain function, so a koan can call it: the koan's process then traps exits, holds the board's state, and receives the idle timer's message, which carries a fresh ref. Trapping turns a linked process's exit into a message, which the catch-all then ignores. 1. At the top of init/1, set the process flag that traps exits. 2. In reset_idle_timer/1, make a ref, start a timer that sends {:idle, ref} to self() after idle_after milliseconds, and keep them as idle_ref and idle_timer." do
    board = board_fixture()
    shape_fixture(board, z: 4)

    assert {:ok, state} = BoardServer.init(slug: board.slug, idle_after: 20)
    assert Process.info(self(), :trap_exit) == {:trap_exit, true}
    assert {map_size(state.shapes), state.next_z} == {1, 5}

    ref = state.idle_ref
    assert is_reference(ref) and is_reference(state.idle_timer)
    assert_receive {:idle, ^ref}, 500
    {:ok, again} = BoardServer.init(slug: board.slug, idle_after: 20)
    refute again.idle_ref == ref
    assert BoardServer.init(slug: "no-such-board") == :ignore
  end

  koan "Implement via/1 so start_link/1 registers the server in Easel.Boards.Registry under its slug: Registry.lookup/2 and GenServer.whereis/1 find it by slug alone, and a second server for that slug is refused." do
    board = board_fixture()
    pid = start_supervised!({BoardServer, slug: board.slug})

    assert Registry.lookup(Easel.Boards.Registry, board.slug) == [{pid, nil}]
    assert GenServer.whereis(BoardServer.via(board.slug)) == pid
    assert BoardServer.start_link(slug: board.slug) == {:error, {:already_started, pid}}
  end

  koan "Implement ensure_started/1 so it starts a board's server under Easel.Boards.BoardSupervisor, hands back the one already running, and answers {:error, :not_found} for a slug with no board. 1. Ask DynamicSupervisor.start_child/2 for a {BoardServer, slug: slug} child. 2. Count an already started server as {:ok, pid}. 3. Turn :ignore into {:error, :not_found}." do
    board = board_fixture()

    assert {:ok, pid} = BoardServer.ensure_started(board.slug)
    assert BoardServer.ensure_started(board.slug) == {:ok, pid}
    children = DynamicSupervisor.which_children(Easel.Boards.BoardSupervisor)
    assert {:undefined, pid, :worker, [BoardServer]} in children
    assert BoardServer.ensure_started("no-such-board") == {:error, :not_found}
  end

  koan "Implement call/2 and the :snapshot clause of handle_call/3 so snapshot/1 answers the shapes lowest z first, even after the server has stopped. A board can stop between the lookup and the call, so the call starts it again. 1. In call/2, GenServer.call the via name; when that exits with {:noproc, _}, run ensure_started/1, match {:ok, _} so a real start error crashes loudly, and call once more; a slug with no board raises. 2. Answer :snapshot with {:reply, shapes, state}." do
    board = board_fixture()
    # Map order would put "over" first; only a sort by z gives this order.
    shape_fixture(board, z: 2, client_id: "over")
    shape_fixture(board, z: 0, client_id: "under")
    {:ok, pid} = BoardServer.ensure_started(board.slug)

    assert Enum.map(BoardServer.snapshot(board.slug), & &1.id) == ["under", "over"]
    :ok = GenServer.stop(pid)
    assert Enum.map(BoardServer.snapshot(board.slug), & &1.id) == ["under", "over"]
    assert {:ok, restarted} = BoardServer.ensure_started(board.slug)
    refute restarted == pid
    assert_raise MatchError, fn -> BoardServer.snapshot("no-such-board") end
  end

  koan "Implement open_save_window/1 and the :save clause of handle_info/2 so an op is saved when its save window ends, not at once, and later ops in that window are saved with it. 1. In open_save_window/1, send self() :save after save_after milliseconds and mark the state dirty?. 2. In handle_info/2, on :save write with save/1 and answer {:noreply, state}." do
    board = board_fixture()
    pid = start_supervised!({BoardServer, slug: board.slug, save_after: 250})

    :ok = BoardServer.apply_op(board.slug, {:add, rect(@a)})
    :ok = BoardServer.apply_op(board.slug, {:move, @a, 70, 80})
    assert :sys.get_state(pid).dirty?
    assert Boards.load_shapes(board) == []

    eventually(fn -> not :sys.get_state(pid).dirty? end)
    assert [%{id: @a, x: 70, y: 80}] = Boards.load_shapes(board)
  end

  koan "Add two clauses to handle_info/2 so a board stops itself, :normal, on its current idle message, and ignores a stale idle message or a stray one. 1. Match {:idle, ref} only when ref is the state's idle_ref, and answer {:stop, :normal, state}. 2. Last, a clause that answers {:noreply, state} to anything else." do
    board = board_fixture()
    pid = start_supervised!({BoardServer, slug: board.slug})
    watch = Process.monitor(pid)

    send(pid, {:idle, make_ref()})
    send(pid, :stray)
    assert BoardServer.snapshot(board.slug) == []
    assert Process.alive?(pid)

    send(pid, {:idle, :sys.get_state(pid).idle_ref})
    assert_receive {:DOWN, ^watch, :process, ^pid, :normal}, 1_000
  end

  koan "A call can wait in a board's mailbox just behind its idle message, so the board stops :normal before it answers and the caller exits with {:normal, _}. Make call/2 retry on that exit too, so the call starts the board again and gets its answer, but never on :shutdown, which means someone is stopping the board on purpose." do
    board = board_fixture()
    shape_fixture(board, client_id: "kept")
    pid = start_supervised!({BoardServer, slug: board.slug})

    :ok = :sys.suspend(pid)
    send(pid, {:idle, :sys.get_state(pid).idle_ref})
    task = Task.async(fn -> BoardServer.snapshot(board.slug) end)
    eventually(fn -> queued(pid) == 2 end)
    :ok = :sys.resume(pid)

    assert [%{id: "kept"}] = Task.await(task)
    refute Process.alive?(pid)

    other = board_fixture()
    stopping = start_supervised!({BoardServer, slug: other.slug}, id: :stopping)
    :ok = :sys.suspend(stopping)
    task = Task.async(fn -> catch_exit(BoardServer.snapshot(other.slug)) end)
    eventually(fn -> queued(stopping) == 1 end)
    :ok = stop_supervised(:stopping)
    assert {:shutdown, _} = Task.await(task)
    assert Registry.lookup(Easel.Boards.Registry, other.slug) == []
  end

  koan "An exception in a callback still runs terminate/2, which saves, and the supervisor restarts the board from the database; :kill skips terminate/2, so the ops in the open save window are lost." do
    board = board_fixture()
    child = {BoardServer, slug: board.slug, save_after: 60_000}
    {:ok, pid} = DynamicSupervisor.start_child(Easel.Boards.BoardSupervisor, child)
    :ok = BoardServer.apply_op(board.slug, {:add, rect(@a)})

    catch_exit(GenServer.call(pid, :no_such_request))
    assert length(Boards.load_shapes(board)) == _a(1)
    eventually(fn -> restarted?(board.slug, pid) end)

    :ok = BoardServer.apply_op(board.slug, {:add, rect(@b)})
    [{restarted, nil}] = Registry.lookup(Easel.Boards.Registry, board.slug)
    Process.exit(restarted, :kill)
    eventually(fn -> restarted?(board.slug, restarted) end)
    assert length(BoardServer.snapshot(board.slug)) == _a(1)
  end

  koan "BoardLive starts a board's server only on the connected mount: the static render leaves the Registry empty, and join/2 runs ensure_started/1, then reads snapshot/1 into the props." do
    board = board_fixture()
    shape_fixture(board)
    path = ~p"/b/#{board.slug}"

    build_conn() |> with_identity("Ada") |> get(path) |> html_response(200)
    assert Registry.lookup(Easel.Boards.Registry, board.slug) == []

    {:ok, view, _html} = live(with_identity(build_conn(), "Ada"), path)
    assert length(Registry.lookup(Easel.Boards.Registry, board.slug)) == _a(1)
    assert length(board_props(view)["shapes"]) == _a(1)
  end
end
