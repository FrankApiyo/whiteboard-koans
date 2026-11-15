defmodule Demo.MixProject do
  use Mix.Project

  # >>> course
  @koans_lib System.get_env("KOANS_LIB", "lib")
  @root Path.dirname(@koans_lib)
  # <<< course

  def project do
    [
      app: :demo,
      version: "0.1.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      # >>> course
      test_paths: [Path.join(@root, "test/koans")],
      # <<< course
      deps: deps()
    ]
  end

  def cli do
    [
      preferred_envs: [
        precommit: :test,
        # >>> course
        koans: :test
        # <<< course
      ]
    ]
  end

  # >>> course
  defp elixirc_paths(:test), do: [@koans_lib, Path.join(@root, "test/support")]
  defp elixirc_paths(:e2e), do: [@koans_lib]
  defp elixirc_paths(_), do: [@koans_lib]
  # <<< course

  defp deps do
    [
      {:phoenix, "~> 1.8.0"},
      # >>> course
      {:koans, path: "course", only: [:dev, :test]}
      # <<< course
    ]
  end
end
