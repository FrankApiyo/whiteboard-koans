defmodule Koans.Ch12.PresenceAndCursorsTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel_web/live/board_live.ex: EaselWeb.BoardLive.track_presence/2, people/1, handle_info/2

  Presence knows who is here. Phoenix.Presence (the Phoenix course's chapter 14) tracks processes
  on a topic, each under a key with a map of metadata, and forgets a process when it exits.
  Presence.track/4 is a call to this node's tracker shard for the topic, and so is
  Presence.list/1, so a list right after your own track already holds you. The list maps each key
  to %{metas: [...]}: several processes can share a key, so metas is a list, and the tracker adds
  a phx_ref to each meta. A lobby of phones:

      {:ok, _ref} = Presence.track(self(), "lobby", "phone-1", %{nick: "kim"})
      Presence.list("lobby")
      #=> %{"phone-1" => %{metas: [%{nick: "kim", phx_ref: "F2x..."}]}}

  Easel keys presence by tab, not by person: join/2 adds a random tab to me (name and colour
  from the session), so the tab is the key and the rest of me the metadata. Ada in two tabs is
  listed twice: ["Ada", "Ada"]. people/1 makes the people prop, one %{tab, name, color} per key
  from its first meta; mount assigns [] (the static render tracks nobody, its me has no tab).

  When a tab joins or leaves, each node's tracker sends a presence_diff to that node's
  subscribers of the topic, BoardLive among them since chapter 11: a %Phoenix.Socket.Broadcast{}
  with event "presence_diff" and a payload of joins and leaves. Other nodes hear of it on the
  trackers' next delta broadcast, every 1.5 s by default, so their lists lag by that much.
  BoardLive just lists again, and live_svelte sends only the people prop. A diff comes a moment
  later: a task works it out once the shard's list has changed, and the shard broadcasts it, so
  a koan waits for Lin's leave on its own subscription, then sends Ada a diff itself. A closed tab's LiveView ends, the tracker drops
  it, and the browser drops its cursor (the TypeScript koans).

      Write:          lib/easel_web/live/board_live.ex:113  (EaselWeb.BoardLive.track_presence/2)
      Exercised by:   test/koans/12_presence_and_cursors_test.exs:75

  API you'll use
    Presence.track/4  Presence.track(self(), "lobby", "phone-1", %{nick: "kim"}) is {:ok, ref}
    Presence.list/1   Presence.list("lobby") maps each key to %{metas: [meta, ...]}
    Boards.topic/1    chapter 11
    Map.delete/2      Map.delete(%{a: 1, b: 2}, :a) is %{b: 2}
    for/1             for {k, %{n: n}} <- %{"a" => %{n: 1}}, do: {k, n} is [{"a", 1}]; an
                      entry that doesn't match the pattern is skipped
    [head | _]        [first | _] = [1, 2] binds first to 1
    assign/2          assign(socket, count: 2) is the socket with count set
    %Phoenix.Socket.Broadcast{}  a presence_diff arrives as this; match on event: "presence_diff"
    send/2            send(view.pid, message), as in chapter 10
    assert_receive/2  assert_receive {:done, _} waits for a message, up to a second here
    GenServer.stop/1  GenServer.stop(view.pid) ends a view, as closing its tab would
    board_props/1     the Board's whole props

  Picture: lessons/svg/12_presence.svg
  """
  use Koans, case: EaselWeb.ConnCase

  import Phoenix.LiveViewTest
  import Easel.BoardsFixtures

  alias Easel.Boards
  alias EaselWeb.{BoardLive, Presence}

  defp open(board, name) do
    {:ok, view, _html} = live(with_identity(build_conn(), name), ~p"/b/#{board.slug}")
    view
  end

  defp names(view),
    do: view |> board_props() |> Map.fetch!("people") |> Enum.map(& &1["name"]) |> Enum.sort()

  defp presence_diff(board) do
    %Phoenix.Socket.Broadcast{
      topic: Boards.topic(board.slug),
      event: "presence_diff",
      payload: %{joins: %{}, leaves: %{}}
    }
  end

  koan "Implement track_presence/2 so a tab shows on the board's topic under its tab, with name and colour as its metadata. 1. Presence.track/4 this process on the board's topic, keyed by me.tab, with me minus :tab as the meta. 2. Answer :ok." do
    me = %{tab: "tab-ada", name: "Ada", color: "#e03131"}
    :ok = BoardLive.track_presence("presence-track", me)

    assert %{"tab-ada" => %{metas: [meta]}} = Presence.list(Boards.topic("presence-track"))
    assert map_size(Presence.list(Boards.topic("presence-track"))) == 1
    assert Map.delete(meta, :phx_ref) == %{name: "Ada", color: "#e03131"}
  end

  koan "Implement people/1, the people prop: one %{tab, name, color} for each tab tracked on the board, from that tab's first meta." do
    :ok = BoardLive.track_presence("presence-people", %{tab: "t2", name: "Ada", color: "#e03131"})
    :ok = BoardLive.track_presence("presence-people", %{tab: "t1", name: "Lin", color: "#1971c2"})
    :ok = BoardLive.track_presence("presence-other", %{tab: "t3", name: "Kim", color: "#2f9e44"})

    assert Enum.sort_by(BoardLive.people("presence-people"), & &1.tab) == [
             %{tab: "t1", name: "Lin", color: "#1971c2"},
             %{tab: "t2", name: "Ada", color: "#e03131"}
           ]
  end

  koan "Implement the presence_diff clause of handle_info/2 so the people prop follows who joins and who leaves: on any diff, list the people again." do
    board = board_fixture()
    :ok = Boards.subscribe(board.slug)
    ada = open(board, "Ada")
    assert names(ada) == ["Ada"]
    lin = open(board, "Lin")
    lin_tab = board_props(lin)["me"]["tab"]

    send(ada.pid, presence_diff(board))
    assert names(ada) == ["Ada", "Lin"]

    GenServer.stop(lin.pid)

    assert_receive %Phoenix.Socket.Broadcast{
      event: "presence_diff",
      payload: %{leaves: %{^lin_tab => _}}
    }

    send(ada.pid, presence_diff(board))
    assert names(ada) == ["Ada"]
  end

  koan "Presence is kept per tab, not per person, so Ada with the board open in two tabs shows twice in the people prop, each with a tab of its own." do
    board = board_fixture()
    first = open(board, "Ada")
    second = open(board, "Ada")

    assert names(second) == __
    [one, two] = board_props(second)["people"]
    assert one["tab"] != two["tab"]
    assert board_props(first)["me"]["tab"] in [one["tab"], two["tab"]]
  end
end
