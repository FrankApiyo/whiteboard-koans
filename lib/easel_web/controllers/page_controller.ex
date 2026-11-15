defmodule EaselWeb.PageController do
  use EaselWeb, :controller

  alias Easel.Boards
  alias EaselWeb.Identity

  def home(conn, _params) do
    render(conn, :home,
      form: Phoenix.Component.to_form(%{"title" => ""}, as: :board),
      boards: recent_boards(Identity.board_slugs(conn))
    )
  end

  defp recent_boards(slugs) do
    by_slug = Map.new(Boards.list_boards(slugs), &{&1.slug, &1})
    for slug <- slugs, board = by_slug[slug], do: board
  end
end
