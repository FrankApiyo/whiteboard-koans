Code.require_file("support/course_runner.exs", __DIR__)

defmodule Verify.RuntimeTest do
  use ExUnit.Case, async: false

  alias Verify.CourseRunner

  @fixtures Path.expand("fixtures/runtime", __DIR__)

  defp run_fixture(case_name, extra_args \\ [], file_suffix \\ "") do
    dir = Path.join(@fixtures, case_name)
    file = Path.join(dir, "00_x_test.exs" <> file_suffix)

    CourseRunner.cmd_mix(["test", file | extra_args],
      env: [{"KOANS_DIR", dir}, {"MIX_TEST_PARTITION", "verify"}],
      stderr_to_stdout: true
    )
  end

  defp run_chapter(case_name, file) do
    dir = Path.join(@fixtures, case_name)

    CourseRunner.cmd_mix(["test", Path.join(dir, file)],
      env: [{"KOANS_DIR", dir}, {"MIX_TEST_PARTITION", "verify"}],
      stderr_to_stdout: true
    )
  end

  defp results(output), do: Regex.scan(~r/^RESULT .*$/m, output) |> List.flatten()

  test "value_blank_fails_at_its_line" do
    {output, _} = run_fixture("value_blank")
    assert results(output) == ["RESULT test 00:4 failed kind=:error error=Koans.Blank line=7"]
  end

  test "earlier_wrong_answer_reported_before_later_blank" do
    {output, _} = run_fixture("wrong_before_blank")

    assert results(output) ==
             ["RESULT test 00:4 failed kind=:error error=ExUnit.AssertionError line=6"]
  end

  test "code_blank_fails_at_its_own_line" do
    {output, _} = run_fixture("code_blank")
    assert results(output) == ["RESULT test 00:7 failed kind=:error error=Koans.Blank line=5"]
  end

  test "code_blank_in_genserver_reports_the_blank" do
    {output, _} = run_fixture("genserver")
    assert results(output) == ["RESULT test 00:13 failed kind=:error error=Koans.Blank line=7"]
  end

  test "code_blank_in_task_kills_the_test_with_a_linked_exit_carrying_the_blank" do
    {output, _} = run_fixture("task")

    assert results(output) ==
             [
               "RESULT test 00:9 failed kind=:linked_exit error=Koans.Blank line=3 file=00_x_test.exs"
             ]
  end

  test "blanked_module_has_no_warnings" do
    {output, _} = run_fixture("no_warnings", ["--warnings-as-errors"])
    refute output =~ "warning:"

    assert results(output) == [
             ~s(RESULT test 00:13 passed meditation="passes when nothing is blank")
           ]
  end

  test "test_name_is_short_and_meditation_is_tagged" do
    {output, _} = run_fixture("long_meditation")
    refute output =~ "SystemLimitError"
    [result] = results(output)
    assert result =~ "RESULT test 00:4 passed meditation=\""
    assert result =~ String.duplicate("long ", 59) <> "long"
  end

  test "nearest_line_runs_one_koan" do
    {output, _} = run_fixture("nearest_line", [], ":9")
    assert results(output) == [~s(RESULT test 00:8 passed meditation="second")]
  end

  test "tagged_blank_footer_names_write_and_exercised_by" do
    {output, _} = run_fixture("tagged")
    dir = "verify/fixtures/runtime/tagged/00_x_test.exs"
    assert output =~ "Write:          #{dir}:3  (Fixture.list/1)\n"
    assert output =~ "Exercised by:   #{dir}:9\n"
    refute output =~ "Meditate on"
  end

  test "blank_in_conn_reports_the_blank" do
    {output, _} = run_fixture("conn")

    assert results(output) == ["RESULT test 00:15 failed kind=:error error=Koans.Blank line=4"]

    dir = "verify/fixtures/runtime/conn/00_x_test.exs"
    assert output =~ "Write:          #{dir}:4  (ConnFixture.Plug.call/2)\n"
    assert output =~ "Exercised by:   #{dir}:15\n"
  end

  test "blank_in_liveview_reports_the_blank" do
    {output, _} = run_fixture("liveview")

    assert results(output) == ["RESULT test 00:13 failed kind=:error error=Koans.Blank line=5"]

    dir = "verify/fixtures/runtime/liveview/00_x_test.exs"
    assert output =~ "Write:          #{dir}:5  (LiveFixture.Live.mount/3)\n"
    assert output =~ "Exercised by:   #{dir}:13\n"

    dir = "verify/fixtures/runtime/liveview/00_x_test.exs"
    assert output =~ "Write:          #{dir}:5  (LiveFixture.Live.mount/3)\n"
    assert output =~ "Exercised by:   #{dir}:13\n"
  end

  test "liveview_reads_db_in_shared_mode" do
    {output, _} = run_fixture("liveview_db")

    assert results(output) == [
             ~s(RESULT test 00:33 passed meditation="reads the database from a live process")
           ]
  end

  describe "defaulted blanks" do
    test "soft_default_keeps_an_earlier_chapter_passing" do
      {output, _} = run_chapter("soft_default", "03_x_test.exs")

      assert results(output) == [
               ~s(RESULT test 03:9 passed meditation="an earlier path keeps working")
             ]
    end

    test "defaulted_blanks_compile_without_warnings" do
      dir = Path.join(@fixtures, "soft_warnings")

      {output, _} =
        CourseRunner.cmd_mix(["test", Path.join(dir, "03_x_test.exs"), "--warnings-as-errors"],
          env: [{"KOANS_DIR", dir}, {"MIX_TEST_PARTITION", "verify"}],
          stderr_to_stdout: true
        )

      refute output =~ "warning:"
      assert [result] = results(output)
      assert result =~ " passed "
    end

    test "soft_blank_is_reported_when_the_koan_is_its_own_chapter" do
      {output, _} = run_chapter("soft_blamed", "05_x_test.exs")
      dir = "verify/fixtures/runtime/soft_blamed/05_x_test.exs"

      assert results(output) == ["RESULT test 05:9 failed kind=:error error=Koans.Blank line=3"]
      assert output =~ "Write:          #{dir}:3  (SoftBlamed.notify/1)\n"
      assert output =~ "Exercised by:   #{dir}:9\n"
    end

    test "a_foreign_soft_hit_leaves_the_original_failure" do
      {output, _} = run_chapter("soft_foreign", "03_x_test.exs")

      assert results(output) ==
               ["RESULT test 03:9 failed kind=:error error=ExUnit.AssertionError line=11"]

      refute output =~ "Write:"
    end

    test "hits_are_cleared_between_koans" do
      {output, _} = run_chapter("soft_clear", "05_x_test.exs")

      assert Enum.sort(results(output)) == [
               "RESULT test 05:13 failed kind=:error error=ExUnit.AssertionError line=14",
               ~s(RESULT test 05:9 passed meditation="passes through a soft blank")
             ]

      refute output =~ "Write:"
    end

    test "the_oldest_soft_hit_is_named" do
      {output, _} = run_chapter("soft_two", "05_x_test.exs")
      dir = "verify/fixtures/runtime/soft_two/05_x_test.exs"

      assert output =~ "Write:          #{dir}:3  (SoftTwo.first/1)\n"
      refute output =~ "SoftTwo.second"
    end

    test "a_hard_hit_wins_over_a_later_soft_one" do
      {output, _} = run_chapter("soft_hard", "05_x_test.exs")
      dir = "verify/fixtures/runtime/soft_hard/05_x_test.exs"

      assert results(output) == ["RESULT test 05:10 failed kind=:error error=Koans.Blank line=3"]
      assert output =~ "Write:          #{dir}:3  (SoftHard.hard/0)\n"
    end

    test "a_soft_hit_in_another_process_is_attributed" do
      {output, _} = run_chapter("soft_server", "05_x_test.exs")
      dir = "verify/fixtures/runtime/soft_server/05_x_test.exs"

      assert [result] = results(output)
      assert result =~ "RESULT test 05:13 failed"
      assert output =~ "Write:          #{dir}:7  (SoftServer.handle_call/3)\n"
      assert output =~ "Exercised by:   #{dir}:13\n"
    end
  end

  test "standalone_success_points_at_mix_koans" do
    {output, _} = run_fixture("standalone")

    assert String.trim_trailing(output) =~
             ~r/All 2 Elixir koans pass\. Run mix koans for the whole course\.\z/

    refute output =~ "Enlightenment"
  end

  describe "json lines" do
    setup do
      dir = Path.join(System.tmp_dir!(), "koans_jsonl_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      %{dir: dir}
    end

    test "jsonl_line_per_koan", %{dir: dir} do
      fixture = Path.join(@fixtures, "jsonl")

      {output, _} =
        CourseRunner.cmd_mix(["test"],
          env: [
            {"KOANS_DIR", fixture},
            {"MIX_TEST_PARTITION", "verify"},
            {"KOANS_RESULTS", dir}
          ],
          stderr_to_stdout: true
        )

      refute output =~ "koans answered"
      refute output =~ "The master says"

      relative = "verify/fixtures/runtime/jsonl/07_x_test.exs"

      records =
        dir
        |> Path.join("ex.jsonl")
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.map(&JSON.decode!/1)

      assert [ok, blank, fail, value] = records

      assert %{
               "kind" => "ex",
               "chapter" => "07",
               "file" => ^relative,
               "line" => 9,
               "order" => 1,
               "status" => "ok",
               "meditation" => "passes",
               "at" => 9,
               "tag" => nil,
               "write" => nil,
               "diff" => nil
             } = ok

      assert %{"status" => "blank", "order" => 2, "line" => 13, "at" => 13, "tag" => "07: list"} =
               blank

      assert blank["write"] == %{"path" => relative, "line" => 3, "where" => "Fixture.list/1"}
      assert blank["diff"] =~ "Replace __() with the code the meditation describes."

      assert %{"status" => "fail", "order" => 3, "line" => 17, "tag" => nil, "write" => nil} =
               fail

      assert fail["diff"] =~ "left:  1"
      assert fail["at"] == 19

      assert %{"status" => "blank", "order" => 4, "tag" => nil, "write" => nil} = value
      assert value["diff"] == "Replace __ with the value that makes this true."
      assert value["at"] == 23
    end
  end
end
