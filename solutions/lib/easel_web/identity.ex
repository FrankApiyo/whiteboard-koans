defmodule EaselWeb.Identity do
  @moduledoc """
  A display name and colour kept in the session, plus the boards this session made.

  As a plug it lets a request through only with a name, and otherwise sends the
  visitor to the name form, remembering where they were going.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [current_path: 1, redirect: 2]

  use EaselWeb, :verified_routes

  @max_name 40
  @max_boards 10

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, "name") do
      conn
    else
      conn
      |> remember_return_to()
      |> redirect(to: ~p"/name")
      |> halt()
    end
  end

  def validate_name(name) when is_binary(name) do
    name = String.trim(name)
    if String.length(name) in 1..@max_name, do: {:ok, name}, else: :error
  end

  def validate_name(_name), do: :error

  def put_identity(conn, name) do
    conn
    |> put_session("name", name)
    |> put_session("color", Easel.Palette.random())
  end

  def pop_return_to(conn) do
    {get_session(conn, "return_to") || ~p"/", delete_session(conn, "return_to")}
  end

  def board_slugs(conn), do: get_session(conn, "board_slugs") || []

  def remember_board(conn, slug) do
    put_session(conn, "board_slugs", Enum.take([slug | board_slugs(conn)], @max_boards))
  end

  defp remember_return_to(%Plug.Conn{method: "GET"} = conn),
    do: put_session(conn, "return_to", current_path(conn))

  defp remember_return_to(conn), do: conn
end
