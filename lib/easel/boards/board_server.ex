defmodule Easel.Boards.BoardServer do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  use GenServer, restart: :transient

  alias Easel.Boards, warn: false
  alias Easel.Boards.Ops, warn: false

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via(Keyword.fetch!(opts, :slug)))
  end

  def via(slug) do
    # >>> 08
    __("08: a Registry via tuple on the slug")
    # <<< 08
  end

  def ensure_started(slug) do
    # >>> 08
    __("08: start under the supervisor, or reuse the running one")
    # <<< 08
  end

  def snapshot(slug), do: call(slug, :snapshot)

  def get_shape(slug, id), do: call(slug, {:get_shape, id})

  def apply_op(slug, op), do: call(slug, {:apply_op, op})

  def announce_restart(slug), do: Boards.broadcast_op(slug, :board_restarted)

  @impl true
  def init(opts) do
    # >>> 08
    __("08: trap exits")
    # <<< 08
    opts = Keyword.merge(Application.get_env(:easel, :board_server, []), opts)

    # A deleted board returns :ignore so the supervisor drops it instead of
    # restarting it until the restart limit stops every board.
    case Boards.get_board_by_slug(Keyword.fetch!(opts, :slug)) do
      nil ->
        :ignore

      board ->
        state = initial_state(board, opts)
        :ok = announce_restart(board.slug)
        {:ok, reset_idle_timer(state)}
    end
  end

  defp initial_state(board, opts) do
    shapes = Boards.load_shapes(board)

    %{
      board: board,
      shapes: Map.new(shapes, &{&1.id, &1}),
      next_z: next_z(shapes),
      dirty?: false,
      save_after: Keyword.fetch!(opts, :save_after),
      idle_after: Keyword.fetch!(opts, :idle_after),
      idle_ref: nil,
      idle_timer: nil
    }
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    # >>> 08
    __("08: reply with the shapes, lowest z first")
    # <<< 08
  end

  def handle_call({:get_shape, id}, _from, state) do
    {:reply, Map.get(state.shapes, id), state}
  end

  def handle_call({:apply_op, op}, _from, state) do
    case Ops.apply(state, op) do
      {:applied, state, event, payload} ->
        :ok = Boards.broadcast_op(state.board.slug, {:board_op, event, payload})
        {:reply, :ok, state |> open_save_window() |> reset_idle_timer()}

      {:ignored, state} ->
        {:reply, :ignored, reset_idle_timer(state)}
    end
  end

  @impl true
  # >>> 08
  def handle_info(_msg, _state), do: __("08: save, stop when idle, ignore the rest")
  # <<< 08

  @impl true
  def terminate(_reason, state), do: save(state)

  # Never retry on :shutdown: that would restart boards while the app or a test
  # is stopping them.
  # >>> 08
  defp call(_slug, _request), do: __("08: call, and retry once on a stopped board")
  # <<< 08

  defp next_z([]), do: 0
  defp next_z(shapes), do: Enum.max_by(shapes, & &1.z).z + 1

  defp open_save_window(%{dirty?: true} = state), do: state

  defp open_save_window(state) do
    # >>> 08
    __("08: schedule :save and mark the state dirty")
    # <<< 08
  end

  defp save(%{dirty?: false} = state), do: state

  defp save(state) do
    {:ok, _count} = Boards.save_shapes(state.board, Map.values(state.shapes))
    %{state | dirty?: false}
  end

  defp reset_idle_timer(state) do
    if state.idle_timer, do: Process.cancel_timer(state.idle_timer)
    # >>> 08
    __("08: a fresh ref, and a timer that sends it")
    # <<< 08
  end
end
