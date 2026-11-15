defmodule Mix.Tasks.Koans do
  @shortdoc "Run the type check, the Elixir koans and the TypeScript koans, then print one footer"
  @moduledoc """
  Runs the whole course in sequence: the type gate, the Elixir koans, the
  TypeScript koans. Prints one footer over both and exits 0 only at Enlightenment.

      mix koans
  """

  use Mix.Task

  @results_dir "_build/koans_results"
  @machine_error ~r/^\d+ ERROR "([^"]+)" (\d+):(\d+) "(.*)"$/

  @impl Mix.Task
  def run(_args) do
    tree = tree_dir()

    tree |> type_check() |> report_type_errors()
    ex_dir = ex_koans_dir()
    ts_dir = ts_koans_dir(tree)

    clear_results()
    run_step("mix", ["test"], "ex.jsonl")
    run_step("npm", ["test"], "ts.jsonl")

    records = Koans.Results.read(@results_dir)
    total = Koans.Footer.total(ex_dir) + Koans.Footer.ts_total(ts_dir)
    footer = Koans.Results.footer(records, total)

    Mix.shell().info(footer)
    unless enlightened?(records, total), do: exit({:shutdown, 1})
  end

  defp verify?, do: System.get_env("KOANS_VERIFY") == "1"

  defp lib_root, do: "KOANS_LIB" |> System.get_env("lib") |> Path.dirname()

  defp tree_dir do
    case {verify?(), System.get_env("KOANS_TS_DIR")} do
      {true, dir} when is_binary(dir) -> Path.dirname(dir)
      _ -> Path.join(lib_root(), "assets")
    end
  end

  defp ex_koans_dir do
    case {verify?(), System.get_env("KOANS_DIR")} do
      {true, dir} when is_binary(dir) -> dir
      _ -> Path.join(lib_root(), "test/koans")
    end
  end

  defp ts_koans_dir(tree) do
    case {verify?(), System.get_env("KOANS_TS_DIR")} do
      {true, dir} when is_binary(dir) -> dir
      _ -> Path.join(tree, "koans")
    end
  end

  defp type_check(tree) do
    args = ["svelte-check", "--tsconfig", Path.join(tree, "tsconfig.json"), "--output", "machine"]
    {output, _status} = System.cmd("npx", args, stderr_to_stdout: true)

    output
    |> String.split("\n", trim: true)
    |> Enum.flat_map(&Regex.scan(@machine_error, &1, capture: :all_but_first))
  end

  defp report_type_errors([]), do: :ok

  defp report_type_errors(errors) do
    lines =
      Enum.map(errors, fn [file, line, col, message] -> "#{file}:#{line}:#{col} #{message}" end)

    Mix.shell().info(
      "Type check failed:\n" <>
        Enum.join(lines, "\n") <>
        "\nFix the types above, then run mix koans again."
    )

    exit({:shutdown, 1})
  end

  defp clear_results do
    File.rm_rf!(@results_dir)
    File.mkdir_p!(@results_dir)
  end

  defp run_step(command, args, results_file) do
    env = [{"KOANS_RESULTS", @results_dir}]
    {output, _status} = System.cmd(command, args, env: env, stderr_to_stdout: true)

    unless File.regular?(Path.join(@results_dir, results_file)) do
      Mix.shell().info(output)
      exit({:shutdown, 1})
    end
  end

  defp enlightened?(records, total) do
    length(records) >= total and Enum.all?(records, &(&1["status"] == "ok"))
  end
end
