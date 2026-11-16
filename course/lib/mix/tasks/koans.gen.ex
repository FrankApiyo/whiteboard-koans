defmodule Mix.Tasks.Koans.Gen do
  @shortdoc "Generate the learner's files and solutions/ from source/"
  @moduledoc """
  Writes `lib/`, `test/support/`, `test/koans/`, `assets/{js,svelte,test,koans}/`
  and `solutions/` (with `solutions/assets/tsconfig.json`) from `source/`.

      mix koans.gen [--only NN,NN] [--root DIR]
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [only: :string, root: :string])
    root = Keyword.get(opts, :root, File.cwd!())
    only = opts |> Keyword.get(:only) |> parse_only()

    case Koans.Gen.write_all(root, only) do
      {:ok, count, []} ->
        Mix.shell().info("wrote #{count} files")

      {:ok, count, backed_up} ->
        Mix.shell().info("wrote #{count} files, replacing #{length(backed_up)} learner files")
        Mix.shell().info(Koans.Gen.Backup.notice())

      {:error, :no_source} ->
        Mix.raise("no source/ directory under #{root}")

      {:error, errors} ->
        Enum.each(errors, fn error -> Mix.shell().error(error) end)
        Mix.raise("source check failed with #{length(errors)} error(s)")
    end
  end

  defp parse_only(nil), do: nil
  defp parse_only(value), do: value |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
end
