defmodule EaselWeb.IdentityHook do
  @moduledoc """
  Gives a LiveView the visitor's name and colour from the session as `@me`.
  """
  use EaselWeb, :verified_routes

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [redirect: 2]

  def on_mount(:require_identity, _params, %{"name" => name, "color" => color}, socket) do
    {:cont, assign(socket, :me, %{name: name, color: color})}
  end

  def on_mount(:require_identity, _params, _session, socket) do
    {:halt, redirect(socket, to: ~p"/name")}
  end
end
