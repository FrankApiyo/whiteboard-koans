defmodule EaselWeb.BoardHelpers do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  @moduledoc """
  Opens a board and adds shapes the way a browser does, for LiveView tests.
  """

  use EaselWeb, :verified_routes

  import ExUnit.Assertions, warn: false
  import Phoenix.ConnTest, warn: false
  import Phoenix.LiveViewTest, warn: false
  import EaselWeb.ConnCase, only: [with_identity: 2]

  @endpoint EaselWeb.Endpoint

  @doc """
  A connected view of `board` for a viewer called `name`.
  """
  def open_board(board, name) do
    conn = build_conn() |> with_identity(name) |> get(~p"/b/#{board.slug}")
    # >>> 14
    __("14: connect the page, and answer the view")
    # <<< 14
  end

  @doc """
  Sends `shape:add` with a whole rect under `attrs`, asserts the server accepted it, and
  answers the payload it sent.
  """
  def add_shape(view, attrs) do
    # >>> 14
    __("14: a whole rect under the attrs, sent and accepted")
    # <<< 14
  end
end
