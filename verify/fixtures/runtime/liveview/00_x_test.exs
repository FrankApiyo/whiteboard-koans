defmodule LiveFixture.Live do
  use Phoenix.LiveView
  import Koans, only: [__: 1]

  def mount(_params, _session, _socket), do: __("10: mount")
  def render(assigns), do: ~H"<p>never</p>"
end

defmodule LiveKoan do
  use Koans, case: EaselWeb.ConnCase
  import Phoenix.LiveViewTest

  koan "mounts" do
    {:ok, _view, html} = live_isolated(build_conn(), LiveFixture.Live)
    assert html =~ "never"
  end
end
