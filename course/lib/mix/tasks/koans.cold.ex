defmodule Mix.Tasks.Koans.Cold do
  @shortdoc "Reset a chapter, then strip its step-by-step meditations"
  @moduledoc """
  Resets chapter NN, then rewrites its koan files (Elixir and TypeScript) cold:
  the blanks are the same, but each meditation gives the behaviour only.

      mix koans.cold NN [--root DIR]
  """

  use Mix.Task

  alias Koans.Gen.Reset

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, strict: [root: :string])
    root = Keyword.get(opts, :root, File.cwd!())

    case positional do
      [chapter] -> chapter |> then(&Reset.cold(root, &1)) |> report(chapter, root)
      _ -> Mix.raise("usage: mix koans.cold NN")
    end
  end

  defp report({:ok, :cold, rels}, _chapter, _root) do
    cold = Enum.map(rels, &"#{&1} is cold: meditations now give the behaviour only.\n")
    Mix.shell().info(Enum.join(cold) <> Koans.Gen.Backup.notice())
  end

  defp report({:ok, :nothing_to_strip, rels}, _chapter, _root) do
    rels
    |> Enum.map_join("\n", &"#{&1} has nothing to strip; it is left as it is.")
    |> Mix.shell().info()
  end

  defp report({:error, message}, _chapter, _root) when is_binary(message), do: Mix.raise(message)

  defp report({:error, :no_source}, _chapter, root),
    do: Mix.raise("no source/ directory under #{root}")

  defp report({:error, :no_chapter}, chapter, root),
    do: Mix.raise(Koans.Gen.Reset.no_chapter(root, chapter))
end
