defmodule EaselWeb.Presence do
  use Phoenix.Presence, otp_app: :easel, pubsub_server: Easel.PubSub
end
