Code.require_file("support/course_runner.exs", __DIR__)

defmodule Verify.KoansTaskTest do
  use ExUnit.Case, async: false

  alias Verify.CourseRunner

  @fixtures "verify/fixtures/koans_task"
  @results Path.join(CourseRunner.root(), "_build/koans_results")

  defp koans(case_name) do
    dir = Path.join(@fixtures, case_name)

    env = [
      {"KOANS_VERIFY", "1"},
      {"KOANS_DIR", Path.join(dir, "test/koans")},
      {"KOANS_TS_DIR", Path.join(dir, "assets/koans")},
      {"KOANS_LIB", nil},
      {"KOANS_RESULTS", nil},
      {"MIX_TEST_PARTITION", "verify"}
    ]

    CourseRunner.mix(["koans"], env)
  end

  setup do
    File.rm_rf!(@results)
    :ok
  end

  defp results_file(name), do: Path.join(@results, name)

  test "type_error_stops_the_run" do
    {output, status} = koans("type_error")
    ts_file = "#{@fixtures}/type_error/assets/koans/01_ts.test.ts"

    assert status == 1, output
    assert output =~ ~r/\AType check failed:/, output
    assert output =~ "#{ts_file}:4:", output
    refute File.exists?(results_file("ex.jsonl")), "no ExUnit run after a type error"
  end

  test "elixir_compile_error_stops_the_run" do
    {output, status} = koans("compile_error")

    assert status == 1, output
    assert output =~ "Compilation error", output
    refute File.exists?(results_file("ex.jsonl"))
    refute output =~ "koans answered"
  end

  test "merged_footer_names_the_earliest_across_kinds" do
    {output, status} = koans("blank_both")

    assert status == 1, output
    assert output =~ ~r{Meditate on \S*test/koans/00_ex_test\.exs:}, output
    refute output =~ "Write:"

    {output, status} = koans("ex_filled")

    assert status == 1, output
    assert output =~ ~r{Write:\s+\S*assets/js/geometry\.ts:\d+  \(01: hit test\)}, output
    assert output =~ "assets/koans/01_ts.test.ts:", output
  end

  test "typescript_first_within_a_chapter" do
    {output, status} = koans("same_chapter")

    assert status == 1, output
    assert output =~ "Write:", output
    refute output =~ "Meditate on", output
    assert output =~ "1 of 4 koans answered.", output
  end

  test "merged_count_spans_both_kinds" do
    {output, _status} = koans("blank_both")

    assert output =~ "1 of 4 koans answered.", output
    assert String.ends_with?(String.trim_trailing(output), "1 of 4 koans answered.")
  end

  test "enlightenment_only_when_both_pass" do
    {output, status} = koans("enlightenment")

    assert status == 0, output
    assert output =~ ~r/-+ Enlightenment -+/, output
    assert output =~ "All 4 koans pass.", output

    {_output, status} = koans("ex_filled")
    assert status == 1
  end
end
