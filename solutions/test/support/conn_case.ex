defmodule EaselWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use EaselWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint EaselWeb.Endpoint

      use EaselWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import EaselWeb.ConnCase
    end
  end

  setup tags do
    Easel.DataCase.setup_sandbox(tags)
    on_exit(&stop_boards/0)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  defdelegate stop_boards, to: Easel.DataCase

  @doc """
  Puts a display name and the first palette colour in the session.
  """
  def with_identity(conn, name) do
    Plug.Test.init_test_session(conn, %{"name" => name, "color" => hd(Easel.Palette.colors())})
  end

  @doc """
  The Board component's whole props, as JSON gives them to the client.

  After the first render live_svelte sends only the props that changed, so
  `LiveSvelte.Test.get_svelte/1` shows a partial map; this reads the view's
  assigns instead.
  """
  def board_props(view) do
    %{socket: socket} = :sys.get_state(view.pid)
    socket.assigns |> EaselWeb.BoardLive.svelte_props() |> Jason.encode!() |> Jason.decode!()
  end
end
