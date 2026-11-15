defmodule Easel.Boards.BoardServer do
  use GenServer, restart: :transient

  alias Easel.Boards
  alias Easel.Boards.Ops

  @supervisor Easel.Boards.BoardSupervisor

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: via(Keyword.fetch!(opts, :slug)))
  end

  def via(slug), do: {:via, Registry, {Easel.Boards.Registry, slug}}

  def ensure_started(slug) do
    case DynamicSupervisor.start_child(@supervisor, {__MODULE__, slug: slug}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      :ignore -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def snapshot(slug), do: call(slug, :snapshot)

  def get_shape(slug, id), do: call(slug, {:get_shape, id})

  def apply_op(slug, op), do: call(slug, {:apply_op, op})

  def announce_restart(slug), do: Boards.broadcast_op(slug, :board_restarted)

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
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
    {:reply, state.shapes |> Map.values() |> Enum.sort_by(& &1.z), state}
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
  def handle_info(:save, state), do: {:noreply, save(state)}

  def handle_info({:idle, ref}, %{idle_ref: ref} = state), do: {:stop, :normal, state}

  def handle_info(_stale_or_stray, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state), do: save(state)

  # :noproc means the board had already stopped; :normal means it stopped for
  # idleness while this call waited. Retrying on :shutdown would restart boards
  # while the app or a test is stopping them.
  defp call(slug, request) do
    GenServer.call(via(slug), request)
  catch
    :exit, {reason, _} when reason in [:noproc, :normal] ->
      {:ok, _pid} = ensure_started(slug)
      GenServer.call(via(slug), request)
  end

  defp next_z([]), do: 0
  defp next_z(shapes), do: Enum.max_by(shapes, & &1.z).z + 1

  defp open_save_window(%{dirty?: true} = state), do: state

  defp open_save_window(state) do
    Process.send_after(self(), :save, state.save_after)
    %{state | dirty?: true}
  end

  defp save(%{dirty?: false} = state), do: state

  defp save(state) do
    {:ok, _count} = Boards.save_shapes(state.board, Map.values(state.shapes))
    %{state | dirty?: false}
  end

  defp reset_idle_timer(state) do
    if state.idle_timer, do: Process.cancel_timer(state.idle_timer)
    ref = make_ref()
    timer = Process.send_after(self(), {:idle, ref}, state.idle_after)
    %{state | idle_ref: ref, idle_timer: timer}
  end
end
