defmodule EaselWeb.BoardHelpers do
  @moduledoc """
  Opens a board and adds shapes the way a browser does, for LiveView tests.
  """

  use EaselWeb, :verified_routes

  import ExUnit.Assertions
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import EaselWeb.ConnCase, only: [with_identity: 2]

  @endpoint EaselWeb.Endpoint

  @doc """
  A connected view of `board` for a viewer called `name`.
  """
  def open_board(board, name) do
    conn = build_conn() |> with_identity(name) |> get(~p"/b/#{board.slug}")
    # >>> answer 14: connect the page, and answer the view
    {:ok, view, _html} = live(conn)
    view
    # <<<
  end

  @doc """
  Sends `shape:add` with a whole rect under `attrs`, asserts the server accepted it, and
  answers the payload it sent.
  """
  def add_shape(view, attrs) do
    # >>> answer 14: a whole rect under the attrs, sent and accepted
    rect = %{"kind" => "rect", "color" => "#e03131", "x" => 10, "y" => 20, "w" => 30, "h" => 40}
    shape = rect |> Map.put("id", Ecto.UUID.generate()) |> Map.merge(attrs)
    render_hook(view, "shape:add", shape)
    assert_reply(view, %{ok: true})
    shape
    # <<<
  end
end
