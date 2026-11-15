defmodule Easel.Repo do
  use Ecto.Repo,
    otp_app: :easel,
    adapter: Ecto.Adapters.SQLite3
end
