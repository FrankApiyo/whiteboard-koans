defmodule EaselWeb.PageController do
  use EaselWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
