conn =
  Phoenix.ConnTest.build_conn()
  |> Plug.Conn.put_req_header("accept", "text/html")
  |> Phoenix.ConnTest.dispatch(EaselWeb.Endpoint, :get, "/name")

IO.puts("CHECKPOINT #{conn.status}")
