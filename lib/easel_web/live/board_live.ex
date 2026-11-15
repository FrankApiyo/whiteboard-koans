defmodule EaselWeb.BoardLive do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  use EaselWeb, :live_view

  alias Easel.{Boards, Shapes}, warn: false
  alias Easel.Boards.BoardServer, warn: false
  alias EaselWeb.Presence, warn: false

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
      <%!-- >>> 06 --%>
      {__("06: the Board component and its props")}
      <%!-- <<< 06 --%>
    </Layouts.app>
    """
  end

  def svelte_props(assigns) do
    # >>> 06
    __("06: the four props from assigns")
    # <<< 06
  end

  @impl true
  def handle_event("shape:add", payload, socket) do
    # >>> 09
    __("09: cast the shape, apply the add, reply")
    # <<< 09
  end

  def handle_event("shape:move", payload, socket) do
    # >>> 09
    __("09: cast the move, apply it, reply")
    # <<< 09
  end

  def handle_event("shape:delete", payload, socket) do
    case Shapes.cast_id(payload) do
      {:ok, id} -> {:reply, run_op(socket, {:delete, id}, id), socket}
      :error -> {:reply, rejected(socket, payload), socket}
    end
  end

  def handle_event("cursor:move", %{"x" => x, "y" => y}, socket)
      when is_integer(x) and is_integer(y) do
    # >>> 11
    __("11: put x and y on me, broadcast it to the others")
    # <<< 11
  end

  def handle_event("cursor:move", _payload, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:board_op, event, payload}, socket) do
    # >>> 10
    __("10: push the op to this view's client", {:noreply, socket})
    # <<< 10
  end

  def handle_info({:cursor, cursor}, socket) do
    # >>> 11
    __("11: push the cursor as cursor:moved")
    # <<< 11
  end

  def handle_info(:board_restarted, socket) do
    slug = socket.assigns.board.slug
    {:noreply, assign(socket, shapes: BoardServer.snapshot(slug), sync_id: sync_id())}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # >>> 12
    __("12: list the people again")
    # <<< 12
  end

  def track_presence(slug, me) do
    # >>> 12
    __("12: track this tab, with the rest of me as metadata", :ok)
    # <<< 12
  end

  def people(slug) do
    # >>> 12
    __("12: one person per tab, from its first meta", [])
    # <<< 12
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
