defmodule Mix.Tasks.Easel.Export do
  @shortdoc "Write a clean copy of the finished app to PATH and commit it"
  @moduledoc """
  Copies the app you built into a new git repository.

      mix easel.export PATH

  Refuses while any blank is left, or when PATH already exists.
  """

  use Mix.Task

  @impl Mix.Task
  def run([path]) do
    case Koans.Export.run(File.cwd!(), path) do
      {:ok, count} ->
        Mix.shell().info("wrote #{count} files to #{path} and made one commit")
        Mix.shell().info("\nCheck it from #{path} (run mix setup first):")
        Mix.shell().info("  mix compile --warnings-as-errors")
        Mix.shell().info("  mix format --check-formatted")
        Mix.shell().info("  mix test")
        Mix.shell().info("  npm test")
        Mix.shell().info("  npm run check")

      {:error, message} ->
        Mix.raise(message)
    end
  end

  def run(_), do: Mix.raise("usage: mix easel.export PATH")
end
