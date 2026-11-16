defmodule Koans.MixProject do
  use Mix.Project

  def project do
    [
      app: :koans,
      version: "0.1.0",
      elixir: "~> 1.18",
      deps: []
    ]
  end

  def application, do: [extra_applications: [:ex_unit, :mix]]
end
