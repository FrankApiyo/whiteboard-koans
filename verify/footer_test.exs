Code.require_file("support/course_runner.exs", __DIR__)

defmodule Verify.FooterTest do
  use ExUnit.Case, async: false

  alias Koans.Footer
  alias Verify.CourseRunner

  @fixtures Path.expand("fixtures/footer", __DIR__)
  @goldens Path.expand("fixtures/footer_golden", __DIR__)
  @ts_koans Path.expand("fixtures/ts/tree/assets/koans", __DIR__)

  defp run_fixture(case_name) do
    dir = Path.join(@fixtures, case_name)

    {output, _} =
      CourseRunner.cmd_mix(["test"],
        env: [{"KOANS_DIR", dir}, {"MIX_TEST_PARTITION", "verify"}],
        stderr_to_stdout: true
      )

    output
  end

  defp fixture_path(case_name, file),
    do: Path.join(["verify/fixtures/footer", case_name, file])

  defp failure(overrides \\ %{}) do
    Map.merge(
      %{path: "koans/02_pattern_matching_test.exs", line: 41, meditation: "M.", diff: nil},
      overrides
    )
  end

  test "render_failure" do
    out = Footer.render(%{passed: 12, total: 350, ran: 350, failure: failure(), scope: :all})

    assert out =~
             "Meditate on koans/02_pattern_matching_test.exs:41\n    M.\n12 of 350 koans answered."

    sep = out |> String.split("\n") |> Enum.find(&(&1 =~ "The master says"))
    assert String.length(sep) == 80
    assert sep =~ ~r/^-+ The master says -+$/
  end

  test "render_failure_shows_the_diff_above_the_separator" do
    out =
      Footer.render(%{
        passed: 0,
        total: 3,
        ran: 3,
        failure: failure(%{diff: "left:  1"}),
        scope: :all
      })

    assert {diff_at, _} = :binary.match(out, "left:  1")
    assert {sep_at, _} = :binary.match(out, "The master says")
    assert diff_at < sep_at
  end

  test "render_two_place" do
    write = %{path: "lib/easel/notes.ex", line: 12, where: {Easel.Notes, :list_notes, 1}}
    failure = failure(%{path: "test/koans/07_notes_test.exs", line: 30, write: write})

    out = Footer.render(%{passed: 3, total: 9, ran: 9, failure: failure, scope: :all})

    assert out =~
             "\nWrite:          lib/easel/notes.ex:12  (Easel.Notes.list_notes/1)\n" <>
               "Exercised by:   test/koans/07_notes_test.exs:30\n    M.\n3 of 9 koans answered."

    refute out =~ "Meditate on"
  end

  test "render_zero_koans_in_an_empty_suite" do
    out = Footer.render(%{passed: 0, total: 0, ran: 0, failure: nil, scope: :all})
    assert out == "No koan at that line: put the cursor inside a koan, or run the file."
  end

  test "location_unwraps_a_plug_wrapper_error" do
    blank = %Koans.Blank{file: "/x/00_a_test.exs", line: 9}
    test = %ExUnit.Test{tags: %{file: "/x/00_a_test.exs", line: 3}}
    wrapped = %{__struct__: Plug.Conn.WrapperError, reason: blank}
    assert Footer.location(test, wrapped, []) == {"/x/00_a_test.exs", 9}
    assert Footer.blank(wrapped) == blank
  end

  test "write_unwraps_a_plug_wrapper_error" do
    blank = %Koans.Blank{file: File.cwd!() <> "/lib/x.ex", line: 7, mfa: {M, :f, 2}}
    wrapped = %{__struct__: Plug.Conn.WrapperError, reason: blank}
    assert Footer.write(wrapped) == %{path: "lib/x.ex", line: 7, where: {M, :f, 2}}
    assert Footer.write(%RuntimeError{}) == nil
  end

  test "render_enlightenment" do
    out = Footer.render(%{passed: 350, total: 350, ran: 350, failure: nil, scope: :all})
    assert out =~ "Enlightenment"
    assert out =~ "All 350 koans pass. Start again with: mix koans.reset all"
    refute out =~ "The master says"
  end

  test "render_partial_pass" do
    out = Footer.render(%{passed: 4, total: 350, ran: 4, failure: nil, scope: :all})
    assert out =~ "4 of 350 koans answered. Run the whole suite for the rest."
    refute out =~ "Enlightenment"
  end

  test "render_when_no_koan_ran" do
    out = Footer.render(%{passed: 0, total: 350, ran: 0, failure: nil, scope: :all})
    assert out == "No koan at that line: put the cursor inside a koan, or run the file."
  end

  test "line_filter_above_every_koan_runs_nothing" do
    {out, _} =
      CourseRunner.cmd_mix(["test", fixture_path("pass", "00_a_test.exs") <> ":1"],
        env: [
          {"KOANS_DIR", Path.join(@fixtures, "pass")},
          {"MIX_TEST_PARTITION", "verify"}
        ],
        stderr_to_stdout: true
      )

    assert out =~ "No koan at that line: put the cursor inside a koan, or run the file."
    refute out =~ "koans answered"
  end

  test "total_counts_koan_lines_across_chapter_files" do
    assert Footer.total(Path.join(@fixtures, "counts")) == 6
    assert Footer.total(Path.join(@fixtures, "earliest")) == 2
  end

  test "location_uses_the_blank_position" do
    blank = %Koans.Blank{file: "/x/00_a_test.exs", line: 9}
    test = %ExUnit.Test{tags: %{file: "/x/00_a_test.exs", line: 3}}
    assert Footer.location(test, blank, []) == {"/x/00_a_test.exs", 9}
  end

  test "location_unwraps_a_linked_exit_reason" do
    blank = %Koans.Blank{file: "/x/00_a_test.exs", line: 9}
    test = %ExUnit.Test{tags: %{file: "/x/00_a_test.exs", line: 3}}
    assert Footer.location(test, {blank, [{Mod, :f, 0, []}]}, []) == {"/x/00_a_test.exs", 9}
  end

  test "location_falls_back_to_the_test_line" do
    test = %ExUnit.Test{tags: %{file: "/x/00_a_test.exs", line: 3}}

    assert Footer.location(test, %RuntimeError{}, [{M, :f, 0, [file: ~c"/lib/m.ex", line: 1]}]) ==
             {"/x/00_a_test.exs", 3}
  end

  test "location_prefers_the_test_file_frame" do
    test = %ExUnit.Test{tags: %{file: "/x/00_a_test.exs", line: 3}}

    stack = [
      {M, :f, 0, [file: ~c"/lib/m.ex", line: 1]},
      {T, :t, 0, [file: ~c"/x/00_a_test.exs", line: 7]}
    ]

    assert Footer.location(test, %RuntimeError{}, stack) == {"/x/00_a_test.exs", 7}
  end

  test "doctests_are_not_counted_as_koans" do
    state = %{passed: 0, ran: 0, failures: [], finished: [], records: []}
    doctest = %ExUnit.Test{state: nil, tags: %{file: "/x/30_a_test.exs", line: 3, doctest: Mod}}
    koan = %ExUnit.Test{state: nil, tags: %{file: "/x/30_a_test.exs", line: 9, meditation: "M."}}

    {:noreply, after_koan} = Koans.Formatter.handle_cast({:test_finished, koan}, state)
    assert %{passed: 1, ran: 1} = after_koan

    {:noreply, after_doctest} = Koans.Formatter.handle_cast({:test_finished, doctest}, after_koan)
    assert after_doctest == after_koan
  end

  test "earliest_failure_wins" do
    out = run_fixture("earliest")
    assert out =~ "Meditate on #{fixture_path("earliest", "00_a_test.exs")}:41"
    assert out =~ "0 of 2 Elixir koans answered."
  end

  test "earliest_selects_by_file_then_line_regardless_of_order" do
    failures = [
      %{path: "b", line: 30, meditation: "", diff: nil, sort_key: {"/k/01_b.exs", 29}},
      %{path: "a", line: 41, meditation: "", diff: nil, sort_key: {"/k/00_a.exs", 40}},
      %{path: "c", line: 9, meditation: "", diff: nil, sort_key: {"/k/00_a.exs", 50}}
    ]

    for shuffled <- [failures, Enum.reverse(failures), Enum.shuffle(failures)] do
      assert %{path: "a", line: 41} = Footer.earliest(shuffled)
    end

    assert Footer.earliest([]) == nil
  end

  test "multi_line_koan_reports_the_failing_assert_line" do
    out = run_fixture("multiline")
    assert out =~ "Meditate on #{fixture_path("multiline", "00_a_test.exs")}:7\n"
  end

  test "raise_shows_its_message" do
    out = run_fixture("raise")
    assert out =~ "boom from the koan\n-"
    assert out =~ "00_a_test.exs:5\n    raises"
  end

  test "assert_receive_shows_its_message" do
    out = run_fixture("receive")
    assert out =~ "Assertion failed, no matching message after 50ms"
    assert out =~ "The master says"
  end

  test "setup_all_failure_names_the_file" do
    out = run_fixture("setup_all")
    assert out =~ "setup exploded"
    assert out =~ "Meditate on #{fixture_path("setup_all", "00_a_test.exs")}"
  end

  test "diff_shows_types" do
    out = run_fixture("diff")
    assert out =~ "left:  1\n"
    assert out =~ "right: 1.0"
    assert out =~ "Meditate on #{fixture_path("diff", "00_a_test.exs")}"
  end

  test "receive_without_after_times_out" do
    run_fixture("timeout")
    {micros, out} = :timer.tc(fn -> run_fixture("timeout") end)
    assert micros < 8_000_000
    assert out =~ "Meditate on #{fixture_path("timeout", "00_a_test.exs")}:5\n    waits forever"
  end

  test "counts_every_pass" do
    assert run_fixture("counts") =~ "5 of 6 Elixir koans answered."
  end

  test "linked_exit_blank_is_reported_at_the_blank" do
    out = run_fixture("linked")
    path = fixture_path("linked", "00_a_test.exs")
    assert out =~ "Write:          #{path}:3  (BlankWork.run/1)\n"
    assert out =~ "Exercised by:   #{path}:9\n"
    assert out =~ "0 of 1 Elixir koans answered."
  end

  test "linked_exit_blank_shows_only_the_blank_message" do
    out = run_fixture("linked")
    assert out =~ "\nReplace __() with the code the meditation describes.\n---"
    refute out =~ "an exception was raised"
    refute out =~ "lib/koans/blank.ex"
  end

  test "linked_crash_with_a_plain_exception_still_prints_a_footer" do
    out = run_fixture("linked_crash")
    path = fixture_path("linked_crash", "00_a_test.exs")
    assert out =~ "Meditate on #{path}:"
    assert out =~ "a linked process raises"
    assert out =~ "boom"
    assert out =~ "0 of 1 Elixir koans answered."
    refute out =~ "Protocol.UndefinedError"
  end

  test "blank_message_names_the_write_line_outside_the_footer" do
    blank = %Koans.Blank{
      message: Koans.Blank.code_message(),
      file: Path.expand("lib/easel/hello.ex"),
      line: 9,
      tag: "00: greet",
      mfa: {Easel.Hello, :greet, 1}
    }

    assert Exception.message(blank) ==
             Koans.Blank.code_message() <>
               "\nWrite:          lib/easel/hello.ex:9  (Easel.Hello.greet/1)"

    value = %Koans.Blank{message: "V.", file: Path.expand("test/koans/00_x_test.exs"), line: 4}
    assert Exception.message(value) == "V."
  end

  test "render_scopes_name_their_language" do
    elixir = Footer.render(%{passed: 1, total: 4, ran: 4, failure: failure(), scope: :elixir})
    assert elixir =~ "1 of 4 Elixir koans answered."

    typescript =
      Footer.render(%{passed: 1, total: 4, ran: 4, failure: failure(), scope: :typescript})

    assert typescript =~ "1 of 4 TypeScript koans answered."
  end

  test "render_standalone_success_points_at_mix_koans" do
    elixir = Footer.render(%{passed: 7, total: 7, ran: 7, failure: nil, scope: :elixir})
    assert elixir == "All 7 Elixir koans pass. Run mix koans for the whole course."

    typescript = Footer.render(%{passed: 3, total: 3, ran: 3, failure: nil, scope: :typescript})
    assert typescript == "All 3 TypeScript koans pass. Run mix koans for the whole course."

    partial = Footer.render(%{passed: 2, total: 7, ran: 2, failure: nil, scope: :elixir})
    assert partial == "2 of 7 Elixir koans answered. Run the whole suite for the rest."
  end

  test "merged_footer_renders_a_typescript_write_line" do
    write = %{path: "assets/js/geometry.ts", line: 42, where: "02: hit test"}
    failure = failure(%{path: "assets/koans/02_x.test.ts", line: 9, write: write})

    out = Footer.render(%{passed: 1, total: 5, ran: 5, failure: failure, scope: :all})

    assert out =~ "\nWrite:          assets/js/geometry.ts:42  (02: hit test)\n"
    assert out =~ "Exercised by:   assets/koans/02_x.test.ts:9\n"
  end

  test "results_order_puts_typescript_first_within_a_chapter" do
    ex = %{"kind" => "ex", "chapter" => "05", "file" => "test/koans/05_x_test.exs", "line" => 3}
    ts = %{"kind" => "ts", "chapter" => "05", "file" => "assets/koans/05_x.test.ts", "line" => 40}
    earlier = %{ex | "chapter" => "04", "line" => 90}

    assert Koans.Results.earliest([ex, ts]) == ts
    assert Koans.Results.earliest([ts, ex]) == ts
    assert Koans.Results.earliest([ts, earlier]) == earlier
    assert Koans.Results.earliest([]) == nil
  end

  test "results_read_reports_a_missing_file" do
    dir =
      Path.join(System.tmp_dir!(), "koans_results_missing_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "ex.jsonl"), "")
    assert Koans.Results.read(dir) == {:error, :missing}
  end

  test "results_footer_merges_both_languages" do
    ok = %{"kind" => "ex", "chapter" => "01", "status" => "ok", "file" => "a", "line" => 1}

    ts_fail = %{
      "kind" => "ts",
      "chapter" => "02",
      "status" => "blank",
      "file" => "assets/koans/02_x.test.ts",
      "line" => 9,
      "at" => 9,
      "meditation" => "M.",
      "diff" => nil,
      "write" => %{"path" => "assets/js/geometry.ts", "line" => 42, "where" => "02: hit test"}
    }

    out = Koans.Results.footer([ok, ts_fail], 6)
    assert out =~ "Write:          assets/js/geometry.ts:42  (02: hit test)"
    assert out =~ "1 of 6 koans answered."

    all_ok = Koans.Results.footer([ok], 1)
    assert all_ok =~ "All 1 koans pass. Start again with: mix koans.reset all"
  end

  test "footer_goldens_render_identically" do
    cases = @goldens |> Path.join("*.json") |> Path.wildcard() |> Enum.sort()
    assert length(cases) >= 7

    for json <- cases do
      input = json |> File.read!() |> JSON.decode!() |> golden_input()
      text = json |> String.replace_suffix(".json", ".txt") |> File.read!()

      assert Footer.render(input) == String.replace_suffix(text, "\n", ""),
             "golden #{Path.basename(json)}"
    end
  end

  defp golden_input(map) do
    %{
      passed: map["passed"],
      total: map["total"],
      ran: map["ran"],
      scope: String.to_existing_atom(map["scope"]),
      failure: golden_failure(map["failure"])
    }
  end

  defp golden_failure(nil), do: nil

  defp golden_failure(failure) do
    %{
      path: failure["path"],
      line: failure["line"],
      meditation: failure["meditation"],
      diff: failure["diff"],
      write: golden_write(failure["write"])
    }
  end

  defp golden_write(nil), do: nil
  defp golden_write(write), do: %{path: write["path"], line: write["line"], where: write["where"]}

  test "typescript_total_counts_top_level_test_lines" do
    assert Footer.ts_total(@ts_koans) == 8
    assert Footer.ts_total(Path.join(@fixtures, "counts")) == 0
  end

  test "results_read_returns_both_files" do
    dir = Path.join(CourseRunner.root(), "tmp/koans_results_read")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "ex.jsonl"), ~s({"kind":"ex","line":3}\n))
    File.write!(Path.join(dir, "ts.jsonl"), ~s({"kind":"ts","line":5}\n{"kind":"ts","line":9}\n))

    assert Koans.Results.read(dir) == [
             %{"kind" => "ex", "line" => 3},
             %{"kind" => "ts", "line" => 5},
             %{"kind" => "ts", "line" => 9}
           ]
  end

  test "results_earliest_skips_passing_koans" do
    ok = %{"kind" => "ts", "chapter" => "00", "status" => "ok", "file" => "a", "line" => 1}
    fail = %{"kind" => "ex", "chapter" => "03", "status" => "fail", "file" => "b", "line" => 7}

    assert Koans.Results.earliest([ok, fail]) == fail
    assert Koans.Results.earliest([ok]) == nil
  end
end
