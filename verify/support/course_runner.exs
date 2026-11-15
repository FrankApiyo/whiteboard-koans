defmodule Verify.CourseRunner do
  @moduledoc false

  @root Path.expand("../..", __DIR__)
  @koan_line ~r/^\s*koan\s+"/
  @ts_koan_line ~r/^test\("/
  @ts_results "tmp/course_results"
  @verify_env [
    {"KOANS_LIB", "_verify/lib"},
    {"MIX_TEST_PARTITION", "chapters"},
    {"MIX_ENV", "test"},
    {"KOANS_DIR", nil},
    {"KOANS_VERIFY", "1"}
  ]
  @compiled_dirs ~w(_verify lib test/support solutions/lib solutions/test/support)

  def root, do: @root

  def only do
    case System.get_env("KOANS_ONLY") do
      nil -> nil
      value -> value |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
    end
  end

  def chapter(path), do: path |> Path.basename() |> String.slice(0, 2)

  def all_chapters do
    (koan_files("source/test/koans") ++ ts_koan_files("source/assets/koans"))
    |> Enum.map(&chapter/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def chapters, do: select(all_chapters(), only())

  defp select(all, nil), do: all

  defp select(all, requested) do
    unknown = requested -- all

    if requested == [] or unknown != [] do
      raise ArgumentError,
            "KOANS_ONLY=#{System.get_env("KOANS_ONLY")} names no chapter in source/ " <>
              "(unknown: #{Enum.join(unknown, ",")}; present: #{Enum.join(all, ",")})"
    end

    Enum.filter(all, &(&1 in requested))
  end

  def koan_files(dir) do
    [@root, dir, "[0-9][0-9]_*_test.exs"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort()
  end

  def ts_koan_files(dir) do
    [@root, dir, "[0-9][0-9]_*.test.ts"]
    |> Path.join()
    |> Path.wildcard()
    |> Enum.sort()
  end

  def selected_files(dir), do: Enum.filter(koan_files(dir), &(chapter(&1) in chapters()))

  def selected_ts_files(dir), do: Enum.filter(ts_koan_files(dir), &(chapter(&1) in chapters()))

  def verify_file(nn), do: "_verify/test/koans" |> koan_files() |> Enum.find(&(chapter(&1) == nn))

  def ts_verify_file(nn),
    do: "_verify/assets/koans" |> ts_koan_files() |> Enum.find(&(chapter(&1) == nn))

  def rel(path), do: Path.relative_to(path, @root)

  def koan_lines(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> Regex.match?(@koan_line, line) end)
    |> Enum.map(&elem(&1, 1))
  end

  def ts_koan_lines(path) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> Regex.match?(@ts_koan_line, line) end)
    |> Enum.map(&elem(&1, 1))
  end

  def mix(args, env \\ []), do: cmd_mix(args, cd: @root, env: env, stderr_to_stdout: true)

  def npm(args, env \\ []),
    do: System.cmd("npm", args, cd: @root, env: env, stderr_to_stdout: true)

  def svelte_check(tree) do
    System.cmd(
      Path.join(@root, "node_modules/.bin/svelte-check"),
      ["--tsconfig", Path.join(tree, "assets/tsconfig.json"), "--fail-on-warnings"],
      cd: @root,
      stderr_to_stdout: true
    )
  end

  @doc """
  Runs the TypeScript koans of the `_verify` tree, limited to the given files and
  any `npm test` arguments, and returns the output, exit status and records.
  """
  def npm_verify(files, args \\ []) do
    results = Path.join(@root, @ts_results)
    File.mkdir_p!(results)
    jsonl = Path.join(results, "ts.jsonl")
    File.write!(jsonl, "")

    {output, status} =
      npm(["test", "--" | files ++ args], [
        {"KOANS_LIB", "_verify/lib"},
        {"KOANS_VERIFY", nil},
        {"KOANS_TS_DIR", nil},
        {"KOANS_RESULTS", @ts_results}
      ])

    {output, status, read_jsonl(jsonl)}
  end

  defp read_jsonl(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&JSON.decode!/1)
  end

  def cmd_mix(args, opts) do
    opts |> Keyword.get(:cd, File.cwd!()) |> await_past_mtimes()
    System.cmd("mix", args, opts)
  end

  # When a template changes, Mix touches the module that embeds it to one second
  # past the compile's start. A Mix run inside that second warns about the mtime.
  defp await_past_mtimes(project) do
    wait = newest_source_mtime(project) * 1000 - System.os_time(:millisecond)

    if wait > 0 do
      Process.sleep(wait)
      await_past_mtimes(project)
    end
  end

  defp newest_source_mtime(project) do
    @compiled_dirs
    |> Enum.flat_map(&Path.wildcard(Path.join([project, &1, "**", "*.{ex,exs,heex}"])))
    |> Enum.map(&File.stat!(&1, time: :posix).mtime)
    |> Enum.max(fn -> 0 end)
  end

  def mix_verify(args, env \\ []), do: mix(args, @verify_env ++ env)

  def test_results(output) do
    ~r/^KOANS-TEST (\S+) (\S+):(\d+)$/m
    |> Regex.scan(output)
    |> Map.new(fn [_, kind, path, line] -> {{path, String.to_integer(line)}, kind} end)
  end

  def blank_results(output) do
    ~r/^KOANS-BLANK (\S+):(\d+) (\S+):(\d+) (.*)$/m
    |> Regex.scan(output)
    |> Map.new(fn [_, path, line, blank_path, blank_line, tag] ->
      {{path, String.to_integer(line)}, {blank_path, String.to_integer(blank_line), tag}}
    end)
  end

  def output_tail(output), do: output |> String.split("\n") |> Enum.take(-60) |> Enum.join("\n")
end
