defmodule Mix.Tasks.Koans do
  @shortdoc "Run the type check, the Elixir koans and the TypeScript koans, then print one footer"
  @moduledoc """
  Runs the whole course in sequence: the type gate, the Elixir koans, the
  TypeScript koans. Prints one footer over both and exits 0 only at Enlightenment.

      mix koans
  """

  use Mix.Task

  @results_dir "_build/koans_results"
  @max_type_errors 5
  @machine_line ~r/^\d+ (ERROR|WARNING) ("(?:[^"\\]|\\.)*") (\d+):(\d+) ("(?:[^"\\]|\\.)*")$/
  @compiler_warning ~r/^\s*warning: /

  @impl Mix.Task
  def run(_args) do
    tree = tree_dir()
    ex_dir = ex_koans_dir()
    ts_dir = ts_koans_dir(tree)

    total = Koans.Footer.total(ex_dir) + Koans.Footer.ts_total(ts_dir)

    clear_results()
    %{errors: errors, warnings: type_warnings} = type_check(tree)
    report_type_errors(errors)
    if total == 0, do: stop("No koans found: nothing to answer.")
    ex_output = run_step("mix", ["test"], "ex.jsonl")
    run_step(command("KOANS_NPM", "npm"), ["test"], "ts.jsonl")

    records = Koans.Results.read(@results_dir)
    footer = Koans.Results.footer(records, total)

    report_warnings(type_warnings ++ compiler_warnings(ex_output))
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

  # --no keeps npx from downloading svelte-check when node_modules is incomplete.
  defp type_check(tree) do
    unless File.dir?("node_modules"), do: stop("node_modules/ is missing: run mix setup")
    config = Path.join(tree, "tsconfig.json")
    args = ["--no", "--", "svelte-check", "--tsconfig", config, "--output", "machine"]
    {output, status} = run_command(command("KOANS_NPX", "npx"), args, [])

    problems =
      output
      |> String.split("\n", trim: true)
      |> Enum.flat_map(&Regex.scan(@machine_line, &1, capture: :all_but_first))
      |> Enum.map(&type_problem/1)

    errors = for {"ERROR", line} <- problems, do: line
    warnings = for {"WARNING", line} <- problems, do: line

    if errors == [] and status != 0 do
      stop("Type check could not run (exit #{status}):\n#{output}")
    end

    %{errors: errors, warnings: warnings}
  end

  defp type_problem([kind, file, line, col, message]) do
    [first | rest] = message |> JSON.decode!() |> String.split("\n")
    continued = Enum.map(rest, &("\n      " <> &1))
    {kind, "  #{JSON.decode!(file)}:#{line}:#{col}  #{first}#{continued}"}
  end

  defp report_type_errors([]), do: :ok

  defp report_type_errors(errors) do
    stop("Type check failed:\n" <> Enum.join(Enum.take(errors, @max_type_errors), "\n"))
  end

  defp compiler_warnings(output) do
    output
    |> String.split("\n")
    |> Enum.reduce({[], nil}, &collect_warning/2)
    |> then(fn {blocks, open} -> Enum.reverse(close_block(blocks, open)) end)
  end

  defp collect_warning(line, {blocks, open}) do
    cond do
      Regex.match?(@compiler_warning, line) -> {close_block(blocks, open), [line]}
      open && String.trim(line) != "" -> {blocks, [line | open]}
      true -> {close_block(blocks, open), nil}
    end
  end

  defp close_block(blocks, nil), do: blocks
  defp close_block(blocks, open), do: [open |> Enum.reverse() |> Enum.join("\n") | blocks]

  defp report_warnings([]), do: :ok

  defp report_warnings(warnings) do
    heading = "Warnings (the exported CI treats these as errors):"
    Mix.shell().info(Enum.join([heading | warnings], "\n") <> "\n")
  end

  defp command(env_var, default), do: System.get_env(env_var, default)

  defp run_command(command, args, env) do
    case System.find_executable(command) do
      nil -> stop("#{command} not found: install Node 24.15 or later (see Setup)")
      path -> System.cmd(path, args, env: env, stderr_to_stdout: true)
    end
  end

  defp stop(message) do
    Mix.shell().info(message)
    exit({:shutdown, 1})
  end

  defp clear_results do
    File.rm_rf!(@results_dir)
    File.mkdir_p!(@results_dir)
  end

  defp run_step(command, args, results_file) do
    env = [{"KOANS_RESULTS", @results_dir}]
    {output, _status} = run_command(command, args, env)

    unless File.regular?(Path.join(@results_dir, results_file)) do
      Mix.shell().info(output)
      exit({:shutdown, 1})
    end

    output
  end

  defp enlightened?(records, total) do
    length(records) >= total and Enum.all?(records, &(&1["status"] == "ok"))
  end
end
