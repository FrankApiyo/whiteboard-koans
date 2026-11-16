defmodule Mix.Tasks.Koans.Reset do
  @shortdoc "Re-blank one chapter, or regenerate every learner file"
  @moduledoc """
  Puts a chapter back to its blanks without touching the learner's code in other chapters.

      mix koans.reset NN [--root DIR]
      mix koans.reset all [--root DIR]
  """

  use Mix.Task

  alias Koans.Gen.Reset

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, strict: [root: :string])
    root = Keyword.get(opts, :root, File.cwd!())

    case positional do
      ["all"] -> reset_all(root)
      [chapter] -> reset_chapter(root, chapter)
      _ -> Mix.raise("usage: mix koans.reset NN | all")
    end
  end

  defp reset_all(root) do
    case Koans.Gen.Project.write_learner(root) do
      {:ok, []} ->
        Mix.shell().info("every learner file was already up to date")

      {:ok, changed} ->
        Mix.shell().info(report("regenerated", changed))

      {:error, :no_source} ->
        Mix.raise("no source/ directory under #{root}")
    end
  end

  defp reset_chapter(root, chapter) do
    case Reset.chapter(root, chapter) do
      {:ok, []} -> Mix.shell().info("chapter #{chapter} was already blank")
      {:ok, changed} -> Mix.shell().info(report("reset chapter #{chapter}", changed))
      {:error, :no_source} -> Mix.raise("no source/ directory under #{root}")
      {:error, :no_chapter} -> Mix.raise(Koans.Gen.Reset.no_chapter(root, chapter))
      {:error, message} -> Mix.raise(message)
    end
  end

  defp report(label, changed) do
    "#{label}: #{Enum.join(changed, " ")}\n#{Koans.Gen.Backup.notice()}"
  end
end
