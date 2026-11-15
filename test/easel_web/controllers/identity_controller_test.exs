defmodule EaselWeb.IdentityControllerTest do
  use EaselWeb.ConnCase

  test "GET /name shows the name form", %{conn: conn} do
    html = conn |> get(~p"/name") |> html_response(200)

    assert html =~ ~s(action="/name")
  end

  test "POST /name keeps the name, gives a palette colour and returns", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{"return_to" => "/b/abc"})
      |> post(~p"/name", %{"identity" => %{"name" => "  Ada  "}})

    assert redirected_to(conn) == "/b/abc"
    assert get_session(conn, "name") == "Ada"
    assert get_session(conn, "color") in Easel.Palette.colors()
    assert get_session(conn, "return_to") == nil
  end

  test "POST /name goes home when there is nowhere to return to", %{conn: conn} do
    conn = post(conn, ~p"/name", %{"identity" => %{"name" => "Ada"}})

    assert redirected_to(conn) == ~p"/"
  end

  test "POST /name rejects a blank or overlong name", %{conn: conn} do
    for name <- ["   ", String.duplicate("a", 41)] do
      conn = post(conn, ~p"/name", %{"identity" => %{"name" => name}})

      assert html_response(conn, 422) =~ ~s(action="/name")
      assert get_session(conn, "name") == nil
    end
  end

  test "the hook halts a socket whose session has no name" do
    socket = %Phoenix.LiveView.Socket{}

    assert {:halt, _socket} = EaselWeb.IdentityHook.on_mount(:require_identity, %{}, %{}, socket)

    session = %{"name" => "Ada", "color" => "#e03131"}

    assert {:cont, socket} =
             EaselWeb.IdentityHook.on_mount(:require_identity, %{}, session, socket)

    assert socket.assigns.me == %{name: "Ada", color: "#e03131"}
  end
end
