defmodule LiveDbFixture.Live do
  use Phoenix.LiveView
  import Ecto.Query

  def mount(_params, _session, socket) do
    parent = self()
    versions = from(m in "schema_migrations", select: m.version)

    spawn(fn ->
      send(parent, {:rows, try_all(versions)})
    end)

    receive do
      {:rows, count} -> {:ok, assign(socket, :count, count)}
    after
      2_000 -> {:ok, assign(socket, :count, :timeout)}
    end
  end

  defp try_all(query) do
    length(Easel.Repo.all(query))
  rescue
    error -> inspect(error.__struct__)
  end

  def render(assigns), do: ~H"<p>rows: {@count}</p>"
end

defmodule LiveDbKoan do
  use Koans, case: EaselWeb.ConnCase
  import Phoenix.LiveViewTest

  koan "reads the database from a live process" do
    {:ok, _view, html} = live_isolated(build_conn(), LiveDbFixture.Live)
    assert html =~ ~r/rows: \d+/
  end
end
