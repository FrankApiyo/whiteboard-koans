defmodule Koans.Ch12.PresenceAndCursorsTest do
  @moduledoc ~S"""
  Files this chapter touches
    - lib/easel_web/live/board_live.ex: EaselWeb.BoardLive.track_presence/2, people/1, handle_info/2

  Presence knows who is here. Phoenix.Presence (the Phoenix course's chapter 14) tracks
  processes on a topic, each under a key with a map of metadata, and forgets a process when it
  exits. Presence.track/4 is a call to the tracker shard that owns the topic, and so is
  Presence.list/1, so a list right after your own track already holds you. The list is a map
  from each key to %{metas: [...]}: several processes can share a key, so metas is a list, and
  the tracker adds a phx_ref to each meta. A lobby that tracks phones, for one:

      {:ok, _ref} = Presence.track(self(), "lobby", "phone-1", %{nick: "kim"})
      Presence.list("lobby")
      #=> %{"phone-1" => %{metas: [%{nick: "kim", phx_ref: "F2x..."}]}}

  Easel keys presence by tab, not by person. me holds name and colour from the session, and
  join/2 adds a random tab, so the tab is the key and the rest of me is the metadata. Ada with
  the board open in two tabs is two presences, listed twice: ["Ada", "Ada"]. people/1 makes the
  people prop from the list, one %{tab, name, color} per key from its first meta. mount assigns
  [] (the static render tracks nobody, and its me has no tab), and join/2 lists them once.

  When a tab joins or leaves, the tracker on each node broadcasts a presence_diff to that
  node's subscribers of the topic: %Phoenix.Socket.Broadcast{event: "presence_diff", payload:
  %{joins: ..., leaves: ...}}. BoardLive has been one since chapter 11. The payload says who
  changed, but BoardLive simply lists again: the list is the truth, and live_svelte sends just
  the people prop. A diff comes a moment later, from a task, so a koan sends one itself.
  Closing a tab ends its LiveView process, the tracker drops its presence, and the next list
  leaves it out; the browser then drops that tab's cursor (this chapter's TypeScript koans).

      Write:          lib/easel_web/live/board_live.ex:111  (EaselWeb.BoardLive.track_presence/2)
      Exercised by:   test/koans/12_presence_and_cursors_test.exs:74

  API you'll use
    Presence.track/4  Presence.track(self(), "lobby", "phone-1", %{nick: "kim"}) is {:ok, ref}
    Presence.list/1   Presence.list("lobby") maps each key to %{metas: [meta, ...]}
    Boards.topic/1    chapter 11
    Map.delete/2      Map.delete(%{a: 1, b: 2}, :a) is %{b: 2}
    for/1             for {k, %{n: n}} <- %{"a" => %{n: 1}}, do: {k, n} is [{"a", 1}]; an
                      entry that doesn't match the pattern is skipped
    [head | _]        [first | _] = [1, 2] binds first to 1
    assign/2          assign(socket, count: 2) is the socket with count set
    %Phoenix.Socket.Broadcast{}  a presence_diff arrives as this struct; match event:
    send/2            send(view.pid, message), as in chapter 10
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
    ada = open(board, "Ada")
    assert names(ada) == ["Ada"]
    lin = open(board, "Lin")

    send(ada.pid, presence_diff(board))
    assert names(ada) == ["Ada", "Lin"]

    GenServer.stop(lin.pid)
    send(ada.pid, presence_diff(board))
    assert names(ada) == ["Ada"]
  end

  koan "Presence is kept per tab, not per person, so Ada with the board open in two tabs shows twice in the people prop, each with a tab of its own." do
    board = board_fixture()
    first = open(board, "Ada")
    second = open(board, "Ada")

    assert names(second) == _a(["Ada", "Ada"])
    [one, two] = board_props(second)["people"]
    assert one["tab"] != two["tab"]
    assert board_props(first)["me"]["tab"] in [one["tab"], two["tab"]]
  end
end
