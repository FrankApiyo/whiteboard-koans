defmodule EaselWeb.BoardControllerTest do
  use EaselWeb.ConnCase

  alias Easel.Boards

  test "POST /boards creates a board, remembers it first and opens it", %{conn: conn} do
    earlier = for n <- 1..10, do: "slug-#{n}"

    conn =
      conn
      |> with_identity("Ada")
      |> init_test_session(%{"board_slugs" => earlier})
      |> post(~p"/boards", %{"board" => %{"title" => "Plan"}})

    [slug | rest] = get_session(conn, "board_slugs")
    assert redirected_to(conn) == ~p"/b/#{slug}"
    assert Boards.get_board_by_slug!(slug).title == "Plan"
    assert rest == Enum.take(earlier, 9)
  end

  test "POST /boards with a blank title goes back home", %{conn: conn} do
    conn = conn |> with_identity("Ada") |> post(~p"/boards", %{"board" => %{"title" => ""}})

    assert redirected_to(conn) == ~p"/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error)
    assert get_session(conn, "board_slugs") == nil
  end

  test "POST /boards without a name redirects to the name form", %{conn: conn} do
    conn = post(conn, ~p"/boards", %{"board" => %{"title" => "Plan"}})

    assert redirected_to(conn) == ~p"/name"
  end
end
