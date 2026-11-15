defmodule DemoWeb.Live do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <ul>
      <%!-- >>> answer 05: list --%>
      <li :for={n <- @notes}>{n}</li>
      <%!-- <<< --%>
    </ul>
    """
  end
end
