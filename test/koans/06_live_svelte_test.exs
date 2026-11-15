defmodule Koans.Ch06.LiveSvelteTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel_web/live/board_live.ex: EaselWeb.BoardLive.render/1, svelte_props/1

  A LiveView hands a Svelte component its props. live_svelte's <.svelte> function component
  renders one div: data-name names the component, data-props holds the props as JSON, and
  phx-hook="SvelteHook" names the browser hook that mounts it. Props go through JSON, so atom
  keys arrive as strings; the browser adds live, the hook itself, to the props it hands down.

      <.svelte name="Clock" props={%{zone: @zone, ticks: 0}} socket={@socket} />

  A page renders twice. The static render answers a plain GET with HTML: mount runs with
  connected?(socket) false, so BoardLive skips join/2 and renders the assigns mount gave it,
  no shapes, sync_id 0 and nobody here. Then the browser connects and mount runs again,
  connected; chapters 08 to 13 fill that path. In a koan, get(conn, path) is the static render
  and get_svelte(html) reads the div back as a map with :name, :id, :props and :ssr among others.
  The hook mounts only after the connected render is patched in, so with SSR off the browser
  never uses the static render's props; koans read them because they need no socket.
  socket={@socket} tells live_svelte the render is connected, so later renders send only the
  props that changed (data-props-diff); without it every render resends them all. Passing
  assigns to svelte_props/1 turns off change tracking for that call; live_svelte diffs itself.

  live_svelte can also render the component on the server (SSR), in Node. Easel turns that off
  with config :live_svelte, ssr: false: a canvas has no server HTML worth sending, and Node
  stays a build tool. So the div's inner target holds no component markup, its text only
  whitespace, "" once trimmed, and :ssr is false, until the hook mounts the component.

      Write:          lib/easel_web/live/board_live.ex:43  (EaselWeb.BoardLive.render/1)
      Exercised by:   test/koans/06_live_svelte_test.exs:71

  API you'll use
    get/2             get(conn, ~p"/b/#{slug}") is the static render; html_response(conn, 200)
    get_svelte/1      get_svelte(html) is %{name: "Clock", props: %{"zone" => "UTC"}, ssr: false}
    <.svelte>         attrs name (the .svelte file's name), props (a map), socket
    svelte_props/1    called with assigns in render/1, and by tests that read the props
    LazyHTML.from_document/1  LazyHTML.from_document(html) parses a page to query
    LazyHTML.query/2  LazyHTML.query(doc, "[data-name=Clock]") is the matching elements
    LazyHTML.attribute/2  LazyHTML.attribute(nodes, "data-name") is ["Clock"], one per node
    LazyHTML.text/1   LazyHTML.text(nodes) is their text; String.trim("\n  ") is ""
    Registry.lookup/2  Registry.lookup(Easel.Boards.Registry, "plan") is [] with no server
    with_identity/2   with_identity(conn, "Ada") puts Ada and the colour "#e03131" in the session
    board_fixture/1, shape_fixture/2  insert a board, and a rect on it, straight through Repo

  Picture: lessons/svg/06_two_renders.svg
  """
  use Koans, case: EaselWeb.ConnCase

  import LiveSvelte.Test
  import Easel.BoardsFixtures

  alias EaselWeb.BoardLive

  defp static_page(board, name \\ "Ada") do
    build_conn()
    |> with_identity(name)
    |> get(~p"/b/#{board.slug}")
    |> html_response(200)
  end

  defp svelte_root(html),
    do: html |> LazyHTML.from_document() |> LazyHTML.query("[data-name=Board]")

  koan "Implement BoardLive.svelte_props/1 so it picks the four props the server sends out of the assigns, and nothing else: shapes, sync_id, me and people." do
    me = %{name: "Lin", color: "#1971c2"}
    assigns = %{shapes: [], sync_id: 7, me: me, people: [], board: %{title: "Plan"}, flash: %{}}

    assert BoardLive.svelte_props(assigns) == %{shapes: [], sync_id: 7, me: me, people: []}
  end

  koan "Fill the HEEx blank in BoardLive.render/1 so the page renders the Board component with svelte_props(assigns) as its props: get_svelte finds a root named Board with those four props, and that root names the hook that mounts it in the browser. 1. Call the <.svelte> function component. 2. Give it the name, the props and @socket." do
    html = static_page(board_fixture(), "Lin")

    assert get_svelte(html).name == "Board"
    keys = get_svelte(html).props |> Map.keys() |> Enum.sort()
    assert keys == ["me", "people", "shapes", "sync_id"]
    assert LazyHTML.attribute(svelte_root(html), "phx-hook") == ["SvelteHook"]
  end

  koan "Props reach the page as JSON, so the atom keys mount assigned come out as strings, and the static render shows mount's defaults." do
    props = get_svelte(static_page(board_fixture(), "Ada")).props

    assert props["me"]["name"] == __
    assert props["me"]["color"] == __
    assert props["sync_id"] == __
  end

  koan "The static render runs before any socket, so it starts no board server and sends no shapes, even for a board with shapes saved." do
    board = board_fixture()
    shape_fixture(board)

    props = get_svelte(static_page(board)).props

    assert props["shapes"] == __
    assert Registry.lookup(Easel.Boards.Registry, board.slug) == __
  end

  koan "With SSR off the server sends the component's div with no component markup, and the browser fills it once the hook mounts Board." do
    html = static_page(board_fixture())
    target = html |> LazyHTML.from_document() |> LazyHTML.query("[data-svelte-target]")

    assert get_svelte(html).ssr == __
    assert String.trim(LazyHTML.text(target)) == __
  end
end
