defmodule EaselWeb.BoardController do
  use EaselWeb, :controller

  alias Easel.Boards
  alias EaselWeb.Identity

  def create(conn, %{"board" => board_params}) do
    case Boards.create_board(board_params) do
      {:ok, board} ->
        conn
        |> Identity.remember_board(board.slug)
        |> redirect(to: ~p"/b/#{board.slug}")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "A board needs a title of up to 80 characters.")
        |> redirect(to: ~p"/")
    end
  end
end
