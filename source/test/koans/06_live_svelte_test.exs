defmodule Koans.Ch06.LiveSvelteTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel_web/live/board_live.ex: EaselWeb.BoardLive.render/1, svelte_props/1

  A LiveView hands a Svelte component its props. live_svelte's <.svelte> function component
  renders one div: data-name names the component, data-props holds the props as JSON, and
  phx-hook="SvelteHook" names the browser hook that mounts it. Props go through Jason, so atom
  keys arrive as strings; the browser adds live, the hook itself, to the props it hands down.

      <.svelte name="Clock" props={%{zone: @zone, ticks: 0}} socket={@socket} />

  A page renders twice. The static render answers a plain GET with HTML: mount runs with
  connected?(socket) false, so BoardLive skips join/2 and renders the assigns mount gave it,
  no shapes, sync_id 0 and nobody here. Then the browser connects and mount runs again,
  connected; chapters 08 to 13 fill that path. In a koan, get(conn, path) is the static render
  and get_svelte(html) reads the div back as a map with :name, :id, :props and :ssr.

  live_svelte can also render the component on the server (SSR), in Node. Easel turns that off
  with config :live_svelte, ssr: false: a canvas has no server HTML worth sending, and Node
  stays a build tool. So the div's inner target holds only whitespace, "" once trimmed, and
  :ssr is false, until the hook mounts the component in the browser.

      Write:          lib/easel_web/live/board_live.ex:43  (EaselWeb.BoardLive.render/1)
      Exercised by:   test/koans/06_live_svelte_test.exs:59

  API you'll use
    get/2             get(conn, ~p"/b/#{slug}") is the static render; html_response(conn, 200)
    get_svelte/1      get_svelte(html) is %{name: "Clock", props: %{"zone" => "UTC"}, ssr: false}
    <.svelte>         <.svelte name="Clock" props={clock_props(assigns)} socket={@socket} />
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

  koan "Fill the HEEx blank in BoardLive.render/1 so the page renders the Board component with svelte_props(assigns) as its props: get_svelte finds a root named Board, and that root names the hook that mounts it in the browser. 1. Call the <.svelte> function component. 2. Give it the name, the props and @socket." do
    html = static_page(board_fixture())

    assert get_svelte(html).name == "Board"
    assert LazyHTML.attribute(svelte_root(html), "phx-hook") == ["SvelteHook"]
  end

  koan "Implement BoardLive.svelte_props/1 so it picks the four props Board.svelte declares out of the assigns, and nothing else: shapes, sync_id, me and people." do
    me = %{name: "Lin", color: "#1971c2"}
    assigns = %{shapes: [], sync_id: 7, me: me, people: [], board: %{title: "Plan"}, flash: %{}}

    assert BoardLive.svelte_props(assigns) == %{shapes: [], sync_id: 7, me: me, people: []}

    props = get_svelte(static_page(board_fixture(), "Lin")).props
    assert Map.keys(props) |> Enum.sort() == ["me", "people", "shapes", "sync_id"]
  end

  koan "Props reach the page as JSON, so the atom keys mount assigned come out as strings, and the static render shows mount's defaults." do
    props = get_svelte(static_page(board_fixture(), "Ada")).props

    assert props["me"]["name"] == _a("Ada")
    assert props["me"]["color"] == _a("#e03131")
    assert props["sync_id"] == _a(0)
  end

  koan "The static render runs before any socket, so it starts no board server and sends no shapes, even for a board with shapes saved." do
    board = board_fixture()
    shape_fixture(board)

    props = get_svelte(static_page(board)).props

    assert props["shapes"] == _a([])
    assert Registry.lookup(Easel.Boards.Registry, board.slug) == _a([])
  end

  koan "With SSR off the server sends the component's div empty, and the browser fills it once the hook mounts Board." do
    html = static_page(board_fixture())
    target = html |> LazyHTML.from_document() |> LazyHTML.query("[data-svelte-target]")

    assert get_svelte(html).ssr == _a(false)
    assert String.trim(LazyHTML.text(target)) == _a("")
  end
end
