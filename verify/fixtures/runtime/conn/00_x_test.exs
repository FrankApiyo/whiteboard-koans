defmodule ConnFixture.Plug do
  import Koans, only: [__: 1]
  def init(opts), do: opts
  def call(_conn, _opts), do: __("01: call")
end

defmodule ConnFixture.Router do
  use Phoenix.Router
  get "/", ConnFixture.Plug, []
end

defmodule ConnKoan do
  use Koans, case: EaselWeb.ConnCase

  koan "dispatches to a plug" do
    conn = Phoenix.ConnTest.dispatch(build_conn(), ConnFixture.Router, :get, "/")
    assert conn.status == 200
  end
end
