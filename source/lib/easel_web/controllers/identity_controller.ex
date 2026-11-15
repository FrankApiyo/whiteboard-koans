defmodule EaselWeb.IdentityController do
  use EaselWeb, :controller

  alias EaselWeb.Identity

  def new(conn, _params) do
    render(conn, :new, form: name_form(""))
  end

  def create(conn, %{"identity" => %{"name" => name}}) do
    case Identity.validate_name(name) do
      {:ok, name} ->
        {return_to, conn} = conn |> Identity.put_identity(name) |> Identity.pop_return_to()
        redirect(conn, to: return_to)

      :error ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:new, form: name_form(name, name: {"use 1 to 40 characters", []}))
    end
  end

  defp name_form(name, errors \\ []) do
    Phoenix.Component.to_form(%{"name" => name}, as: :identity, errors: errors)
  end
end
