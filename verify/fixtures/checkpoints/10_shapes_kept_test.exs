defmodule Verify.Checkpoints.ShapesKeptTest do
  use EaselWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Easel.BoardsFixtures

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
  @rect %{
    "id" => @id,
    "kind" => "rect",
    "color" => "#e03131",
    "x" => 10,
    "y" => 20,
    "w" => 30,
    "h" => 40
  }

  test "a shape one view adds is in the props of a view opened after it", %{conn: conn} do
    board = board_fixture()
    path = ~p"/b/#{board.slug}"

    {:ok, ada, _html} = live(with_identity(conn, "Ada"), path)
    render_hook(ada, "shape:add", @rect)
    assert_reply ada, %{ok: true}

    {:ok, fresh, _html} = live(with_identity(build_conn(), "Lin"), path)
    assert [%{"id" => @id, "kind" => "rect", "x" => 10}] = board_props(fresh)["shapes"]
  end
end
