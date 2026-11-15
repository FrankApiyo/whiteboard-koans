defmodule Verify.Checkpoints.BoardPageTest do
  use EaselWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import LiveSvelte.Test

  test "a named visitor creates a board and its page mounts with the board's props", %{
    conn: conn
  } do
    conn = conn |> with_identity("Ada") |> post(~p"/boards", board: %{title: "Checkpoint"})
    assert "/b/" <> slug = redirected_to(conn)

    {:ok, view, html} = live(with_identity(build_conn(), "Ada"), ~p"/b/#{slug}")

    assert %{name: "Board"} = get_svelte(html)
    props = board_props(view)
    assert props["shapes"] == []
    assert is_integer(props["sync_id"]) and props["sync_id"] > 0
    assert props["me"]["name"] == "Ada"
  end
end
