defmodule EaselWeb.BoardLive do
  use EaselWeb, :live_view

  alias Easel.{Boards, Shapes}
  alias Easel.Boards.BoardServer
  alias EaselWeb.Presence

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    board = Boards.get_board_by_slug!(slug)
    socket = assign(socket, board: board, shapes: [], sync_id: 0, people: [])

    if connected?(socket) do
      {:ok, join(socket, slug)}
    else
      {:ok, socket}
    end
  end

  defp join(socket, slug) do
    me = Map.put(socket.assigns.me, :tab, tab_id())
    {:ok, _pid} = BoardServer.ensure_started(slug)
    :ok = Boards.subscribe(slug)
    :ok = track_presence(slug, me)

    assign(socket,
      me: me,
      people: people(slug),
      shapes: BoardServer.snapshot(slug),
      sync_id: sync_id()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>{@board.title}</.header>
      <%!-- >>> answer 06: the Board component and its props --%>
      <.svelte name="Board" props={svelte_props(assigns)} socket={@socket} />
      <%!-- <<< --%>
    </Layouts.app>
    """
  end

  def svelte_props(assigns) do
    # >>> answer 06: the four props from assigns
    %{shapes: assigns.shapes, sync_id: assigns.sync_id, me: assigns.me, people: assigns.people}
    # <<<
  end

  @impl true
  def handle_event("shape:add", payload, socket) do
    # >>> answer 09: cast the shape, apply the add, reply
    case Shapes.cast(payload) do
      {:ok, shape} -> {:reply, run_op(socket, {:add, shape}, shape.id), socket}
      {:error, _changeset} -> {:reply, rejected(socket, payload), socket}
    end
    # <<<
  end

  def handle_event("shape:move", payload, socket) do
    # >>> answer 09: cast the move, apply it, reply
    case Shapes.cast_move(payload) do
      {:ok, %{id: id, x: x, y: y}} -> {:reply, run_op(socket, {:move, id, x, y}, id), socket}
      :error -> {:reply, rejected(socket, payload), socket}
    end
    # <<<
  end

  def handle_event("shape:delete", payload, socket) do
    case Shapes.cast_id(payload) do
      {:ok, id} -> {:reply, run_op(socket, {:delete, id}, id), socket}
      :error -> {:reply, rejected(socket, payload), socket}
    end
  end

  def handle_event("cursor:move", %{"x" => x, "y" => y}, socket)
      when is_integer(x) and is_integer(y) do
    cursor = Map.merge(socket.assigns.me, %{x: x, y: y})
    topic = Boards.topic(socket.assigns.board.slug)
    Phoenix.PubSub.broadcast_from(Easel.PubSub, self(), topic, {:cursor, cursor})
    {:noreply, socket}
  end

  def handle_event("cursor:move", _payload, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:board_op, event, payload}, socket) do
    # >>> answer 10: push the op to this view's client | default: {:noreply, socket}
    {:noreply, push_event(socket, event, payload)}
    # <<<
  end

  def handle_info({:cursor, cursor}, socket) do
    {:noreply, push_event(socket, "cursor:moved", cursor)}
  end

  def handle_info(:board_restarted, socket) do
    slug = socket.assigns.board.slug
    {:noreply, assign(socket, shapes: BoardServer.snapshot(slug), sync_id: sync_id())}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, people: people(socket.assigns.board.slug))}
  end

  def track_presence(slug, me) do
    {:ok, _ref} = Presence.track(self(), Boards.topic(slug), me.tab, Map.delete(me, :tab))
    :ok
  end

  def people(slug) do
    for {tab, %{metas: [meta | _]}} <- Presence.list(Boards.topic(slug)) do
      %{tab: tab, name: meta.name, color: meta.color}
    end
  end

  defp run_op(socket, op, id) do
    slug = socket.assigns.board.slug

    case BoardServer.apply_op(slug, op) do
      :ok -> %{ok: true}
      :ignored -> %{ok: false, shape: BoardServer.get_shape(slug, id)}
    end
  end

  defp rejected(socket, payload) do
    case Shapes.cast_id(payload) do
      {:ok, id} -> %{ok: false, shape: BoardServer.get_shape(socket.assigns.board.slug, id)}
      :error -> %{ok: false, shape: nil}
    end
  end

  defp tab_id, do: 12 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp sync_id, do: System.unique_integer([:positive])
end
