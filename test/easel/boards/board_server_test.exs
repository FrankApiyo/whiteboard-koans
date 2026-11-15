defmodule Easel.Boards.BoardServerTest do
  use Easel.DataCase

  import Easel.BoardsFixtures

  alias Easel.Boards
  alias Easel.Boards.BoardServer

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"

  defp rect(attrs \\ %{}) do
    Map.merge(%{id: @id, kind: "rect", color: "#e03131", x: 10, y: 20, w: 30, h: 40}, attrs)
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

  setup do
    %{board: board_fixture()}
  end

  test "ensure_started starts one server per board and reports the running one", %{board: board} do
    assert {:ok, pid} = BoardServer.ensure_started(board.slug)
    assert {:ok, ^pid} = BoardServer.ensure_started(board.slug)
    assert [{^pid, _}] = Registry.lookup(Easel.Boards.Registry, board.slug)
  end

  test "start loads saved shapes and announces the restart", %{board: board} do
    shape_fixture(board, z: 2, client_id: "b")
    shape_fixture(board, z: 0, client_id: "a")
    Boards.subscribe(board.slug)

    {:ok, _pid} = BoardServer.ensure_started(board.slug)

    assert_receive :board_restarted
    assert [%{id: "a", z: 0}, %{id: "b", z: 2}] = BoardServer.snapshot(board.slug)
  end

  test "an applied op is broadcast and an ignored op is not", %{board: board} do
    {:ok, _pid} = BoardServer.ensure_started(board.slug)
    Boards.subscribe(board.slug)

    assert BoardServer.apply_op(board.slug, {:add, rect()}) == :ok
    assert_receive {:board_op, "shape:added", %{id: @id, z: 0}}

    assert BoardServer.apply_op(board.slug, {:delete, Ecto.UUID.generate()}) == :ignored
    refute_receive {:board_op, _, _}
  end

  test "get_shape returns the shape or nil", %{board: board} do
    {:ok, _pid} = BoardServer.ensure_started(board.slug)
    :ok = BoardServer.apply_op(board.slug, {:add, rect()})

    assert %{id: @id, x: 10} = BoardServer.get_shape(board.slug, @id)
    assert BoardServer.get_shape(board.slug, Ecto.UUID.generate()) == nil
  end

  test "saves when the save window ends, not at once", %{board: board} do
    start_supervised!({BoardServer, slug: board.slug, save_after: 100})

    :ok = BoardServer.apply_op(board.slug, {:add, rect()})

    assert Boards.load_shapes(board) == []
    eventually(fn -> match?([%{id: @id}], Boards.load_shapes(board)) end)
  end

  test "stops when idle and flushes the pending save", %{board: board} do
    pid = start_supervised!({BoardServer, slug: board.slug, save_after: 60_000, idle_after: 50})
    ref = Process.monitor(pid)

    :ok = BoardServer.apply_op(board.slug, {:add, rect()})

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
    assert [%{id: @id}] = Boards.load_shapes(board)
  end

  test "an op postpones the idle stop", %{board: board} do
    pid = start_supervised!({BoardServer, slug: board.slug, idle_after: 600})
    ref = Process.monitor(pid)
    Process.sleep(400)

    :ok = BoardServer.apply_op(board.slug, {:add, rect()})

    refute_receive {:DOWN, ^ref, _, _, _}, 400
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
  end

  test "a call after the server stopped starts a new one", %{board: board} do
    {:ok, pid} = BoardServer.ensure_started(board.slug)
    :ok = BoardServer.apply_op(board.slug, {:add, rect()})
    :ok = GenServer.stop(pid)

    assert [%{id: @id}] = BoardServer.snapshot(board.slug)
    assert {:ok, new_pid} = BoardServer.ensure_started(board.slug)
    refute new_pid == pid
  end

  test "a call that lands while the server stops for idleness is retried", %{board: board} do
    shape_fixture(board, client_id: "a")
    pid = start_supervised!({BoardServer, slug: board.slug, idle_after: 50})
    queued = fn -> Process.info(pid, :message_queue_len) end
    :ok = :sys.suspend(pid)
    eventually(fn -> queued.() == {:message_queue_len, 1} end)

    task = Task.async(fn -> BoardServer.snapshot(board.slug) end)
    eventually(fn -> queued.() == {:message_queue_len, 2} end)
    :ok = :sys.resume(pid)

    assert [%{id: "a"}] = Task.await(task)
    refute Process.alive?(pid)
  end

  test "stray and stale messages are ignored", %{board: board} do
    {:ok, pid} = BoardServer.ensure_started(board.slug)

    send(pid, :stray)
    send(pid, {:idle, make_ref()})

    assert BoardServer.snapshot(board.slug) == []
    assert Process.alive?(pid)
  end

  test "a killed server restarts from the database", %{board: board} do
    {:ok, pid} = BoardServer.ensure_started(board.slug)
    :ok = BoardServer.apply_op(board.slug, {:add, rect()})
    eventually(fn -> Boards.load_shapes(board) != [] end)
    Boards.subscribe(board.slug)

    Process.exit(pid, :kill)

    assert [%{id: @id}] = BoardServer.snapshot(board.slug)
    assert_receive :board_restarted
    refute BoardServer.ensure_started(board.slug) == {:ok, pid}
  end

  test "crashes on other boards leave the supervisor and this board running", %{board: board} do
    {:ok, bystander} = BoardServer.ensure_started(board.slug)
    supervisor = Process.whereis(Easel.Boards.BoardSupervisor)

    for _ <- 1..6 do
      {:ok, pid} = BoardServer.ensure_started(board_fixture().slug)
      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
    end

    assert %{specs: 7} = DynamicSupervisor.count_children(supervisor)
    assert Process.alive?(supervisor)
    assert Process.alive?(bystander)
  end

  test "a board deleted while running is not restarted", %{board: board} do
    {:ok, bystander} = BoardServer.ensure_started(board.slug)
    supervisor = Process.whereis(Easel.Boards.BoardSupervisor)
    deleted = board_fixture()
    {:ok, pid} = BoardServer.ensure_started(deleted.slug)
    ref = Process.monitor(pid)
    Easel.Repo.delete!(deleted)

    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

    assert BoardServer.ensure_started(deleted.slug) == {:error, :not_found}
    assert %{specs: 1} = DynamicSupervisor.count_children(supervisor)
    assert Process.alive?(supervisor)
    assert Process.alive?(bystander)
  end

  test "stop_boards_flushes_dirty_boards", %{board: board} do
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Easel.Boards.BoardSupervisor,
        {BoardServer, slug: board.slug, save_after: 60_000}
      )

    :ok = BoardServer.apply_op(board.slug, {:add, rect()})
    assert Boards.load_shapes(board) == []

    stop_boards()

    assert DynamicSupervisor.which_children(Easel.Boards.BoardSupervisor) == []
    assert [%{id: @id}] = Boards.load_shapes(board)
  end
end
