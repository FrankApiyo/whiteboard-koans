defmodule EaselWeb.PageControllerTest do
  use EaselWeb.ConnCase

  import Easel.BoardsFixtures

  test "GET / without a name redirects to the name form", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/name"
    assert get_session(conn, "return_to") == ~p"/"
  end

  test "GET / shows the create form and only this session's boards, newest first", %{conn: conn} do
    older = board_fixture(title: "Older")
    newer = board_fixture(title: "Newer")
    board_fixture(title: "Someone else's")

    html =
      conn
      |> with_identity("Ada")
      |> init_test_session(%{"board_slugs" => [newer.slug, older.slug]})
      |> get(~p"/")
      |> html_response(200)

    assert html =~ ~s(action="/boards")
    assert html =~ ~r/Newer.*Older/s
    assert html =~ ~p"/b/#{newer.slug}"
    refute html =~ "Someone else"
  end
end
