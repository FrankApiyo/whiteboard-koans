Code.require_file("support/course_runner.exs", __DIR__)

defmodule Verify.TsRuntimeTest do
  use ExUnit.Case, async: false

  alias Verify.CourseRunner

  @tree "verify/fixtures/ts/tree/assets"
  @koans "#{@tree}/koans"
  @results "tmp/ts_runtime_results"
  @golden Path.expand("fixtures/footer_golden/ts_tree_standalone.txt", __DIR__)
  @value_message "Replace __ with the value that makes this true."
  @code_message "Replace __blank() with the code the meditation describes."

  defp npm_test(env, koans \\ @koans) do
    System.cmd("npm", ["test"],
      cd: CourseRunner.root(),
      env: koans_env(koans, env),
      stderr_to_stdout: true
    )
  end

  defp koans_env(koans, env),
    do: [{"KOANS_VERIFY", "1"}, {"KOANS_TS_DIR", koans}, {"KOANS_LIB", nil} | env]

  defp reset_results(results) do
    dir = Path.join(CourseRunner.root(), results)
    File.mkdir_p!(dir)
    file = Path.join(dir, "ts.jsonl")
    File.write!(file, "")
    file
  end

  defp read_records(file) do
    file
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&JSON.decode!/1)
  end

  setup_all do
    file = reset_results(@results)
    {output, _status} = npm_test([{"KOANS_RESULTS", @results}])
    %{records: read_records(file), output: output}
  end

  defp record(records, name, line) do
    file = "#{@koans}/#{name}"
    Enum.find(records, &(&1["file"] == file and &1["line"] == line))
  end

  test "results_mode_prints_no_footer", %{output: output, records: records} do
    assert length(records) == 8, output
    refute output =~ "koans answered"
    refute output =~ "The master says"
  end

  test "value_blank_fails_at_its_line", %{records: records} do
    assert %{
             "kind" => "ts",
             "chapter" => "00",
             "order" => 2,
             "status" => "blank",
             "meditation" => "an area is a number you can name",
             "at" => 11,
             "tag" => nil,
             "write" => nil,
             "diff" => @value_message
           } = record(records, "00_values.test.ts", 9)

    assert %{"status" => "ok", "order" => 1, "at" => 5, "diff" => nil} =
             record(records, "00_values.test.ts", 5)
  end

  test "code_blank_names_the_tag_location", %{records: records} do
    assert %{
             "chapter" => "01",
             "order" => 1,
             "status" => "blank",
             "at" => 5,
             "tag" => "01: hit test",
             "diff" => @code_message,
             "write" => %{
               "path" => "#{@tree}/js/geometry.ts",
               "line" => 13,
               "where" => "01: hit test"
             }
           } == Map.drop(record(records, "01_code.test.ts", 5), ~w(kind file line meditation))
  end

  test "markup_blank_in_a_component_is_reported_as_its_blank", %{records: records} do
    assert %{
             "status" => "blank",
             "at" => 7,
             "tag" => "03: people list",
             "diff" => @code_message,
             "write" => %{
               "path" => "#{@tree}/svelte/PeopleList.svelte",
               "line" => 9,
               "where" => "03: people list"
             }
           } = record(records, "03_markup.test.ts", 7)
  end

  test "async_koan_failure_is_classified", %{records: records} do
    assert %{
             "order" => 2,
             "status" => "fail",
             "at" => 11,
             "tag" => nil,
             "write" => nil,
             "diff" => "expected: 2\nreceived: 1"
           } = record(records, "01_code.test.ts", 9)

    assert %{"order" => 3, "status" => "blank", "at" => 14, "tag" => "01: hit test"} =
             record(records, "01_code.test.ts", 14)
  end

  test "files_run_in_name_order", %{records: records} do
    files = records |> Enum.map(& &1["file"]) |> Enum.dedup()

    assert files == [
             "#{@koans}/00_values.test.ts",
             "#{@koans}/01_code.test.ts",
             "#{@koans}/03_markup.test.ts"
           ]

    big = File.stat!(Path.join(CourseRunner.root(), "#{@koans}/01_code.test.ts")).size
    small = File.stat!(Path.join(CourseRunner.root(), "#{@koans}/00_values.test.ts")).size
    assert big > small, "the size order must differ from the name order"
  end

  test "standalone_footer_matches_elixir_golden" do
    {output, _status} = npm_test([{"KOANS_RESULTS", nil}])
    golden = @golden |> File.read!() |> String.replace_suffix("\n", "")

    assert golden =~ "2 of 8 TypeScript koans answered."
    assert String.ends_with?(String.trim_trailing(output), golden), output
  end

  test "type_checks_with_every_blank" do
    for {file, blank} <- [
          {"js/geometry.ts", ~s{__blank("01: hit test")}},
          {"svelte/PeopleList.svelte", ~s{__blank("03: people list", "")}},
          {"koans/00_values.test.ts", "toBe(__)"}
        ] do
      assert File.read!(Path.join([CourseRunner.root(), @tree, file])) =~ blank
    end

    {output, status} =
      System.cmd(
        Path.join(CourseRunner.root(), "node_modules/.bin/svelte-check"),
        ["--tsconfig", "#{@tree}/tsconfig.json", "--fail-on-warnings", "--output", "machine"],
        cd: CourseRunner.root(),
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ ~r/COMPLETED [1-9]\d* FILES 0 ERRORS 0 WARNINGS/
  end

  test "handler_blank_is_reported_with_its_write_line", %{records: records} do
    assert %{
             "order" => 2,
             "status" => "blank",
             "at" => 12,
             "tag" => "03: clear board",
             "diff" => @code_message,
             "write" => %{
               "path" => "#{@tree}/svelte/ClearButton.svelte",
               "line" => 5,
               "where" => "03: clear board"
             }
           } = record(records, "03_markup.test.ts", 12)
  end

  test "load_failures_are_reported" do
    load = "verify/fixtures/ts/load/assets"
    results = "tmp/ts_load_results"
    file = reset_results(results)

    {output, _status} = npm_test([{"KOANS_RESULTS", results}], "#{load}/koans")

    assert [blank, fail] = read_records(file), output
    blank_file = "#{load}/koans/00_import_blank.test.ts"
    boot = "#{load}/js/boot.ts"
    broken = "#{load}/koans/01_broken.test.ts"

    assert %{
             "file" => ^blank_file,
             "line" => 5,
             "status" => "blank",
             "at" => 5,
             "tag" => "00: boot",
             "diff" => @code_message,
             "write" => %{"path" => ^boot, "line" => 3, "where" => "00: boot"}
           } = blank

    assert blank["meditation"] =~ "00_import_blank.test.ts"

    assert %{"file" => ^broken, "status" => "fail", "write" => nil} =
             fail

    assert fail["meditation"] =~ "01_broken.test.ts"
    assert fail["diff"] =~ "JSON"
  end

  test "paths_resolve_from_the_repo_root" do
    results = "tmp/ts_cwd_results"
    file = reset_results(results)
    root = CourseRunner.root()

    {output, _status} =
      System.cmd(
        Path.join(root, "node_modules/.bin/vitest"),
        ["run", "--config", Path.join(root, "assets/vitest.config.ts")],
        cd: Path.join(root, "tmp"),
        env: koans_env(@koans, [{"KOANS_RESULTS", results}]),
        stderr_to_stdout: true
      )

    records = read_records(file)
    assert length(records) == 8, output
    assert Enum.all?(records, &String.starts_with?(&1["file"], @koans <> "/"))
    assert record(records, "01_code.test.ts", 5)["write"]["path"] == "#{@tree}/js/geometry.ts"
  end
end
