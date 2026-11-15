Code.require_file("support/course_runner.exs", __DIR__)

defmodule Verify.CourseTest do
  use ExUnit.Case, async: false

  import Verify.CourseRunner

  alias Koans.{ApiCheck, Chapters, Gen, Ts}
  alias Koans.Gen.Project

  @moduletag timeout: 1_800_000

  @checkpoints "verify/fixtures/checkpoints"

  defp assert_passes(output, status) do
    assert output =~ ~r/^KOANS-RESULT ok$/m, output_tail(output)
    assert status == 0, output_tail(output)
    refute output =~ "warning:", output_tail(output)
  end

  defp assert_types_clean(tree) do
    {output, status} = svelte_check(tree)
    assert status == 0, output_tail(output)
  end

  defp own_blank?(nn, rel, {"Koans.Blank", {blank_path, _line, tag}}),
    do: blank_path == rel or String.starts_with?(tag, nn <> ":")

  defp own_blank?(_nn, _rel, _other), do: false

  defp own_ts_blank?(nn, %{"status" => "blank", "tag" => tag}),
    do: tag == nil or String.starts_with?(tag, nn <> ":")

  defp own_ts_blank?(_nn, _record), do: false

  defp record_lines(records, rel),
    do: for(%{"file" => ^rel, "line" => line} <- records, do: line) |> Enum.sort()

  for nn <- chapters() do
    @nn nn

    test "chapter_#{nn}_fails_as_its_own_blanks" do
      :ok = Chapters.build(String.to_integer(@nn) - 1)
      assert_types_clean("_verify")
      ex = verify_file(@nn)
      ts = ts_verify_file(@nn)
      assert ex || ts, "chapter #{@nn} has no koan file in _verify"
      if ex, do: assert_ex_chapter_fails(@nn, rel(ex))
      if ts, do: assert_ts_chapter_fails(@nn, rel(ts))
    end

    test "chapter_#{nn}_passes_and_earlier_still_pass" do
      :ok = Chapters.build(String.to_integer(@nn))
      assert_types_clean("_verify")

      ex = for path <- koan_files("_verify/test/koans"), chapter(path) <= @nn, do: rel(path)
      ts = for path <- ts_koan_files("_verify/assets/koans"), chapter(path) <= @nn, do: rel(path)

      if ex != [] do
        {output, status} = mix_verify(["test", "--warnings-as-errors" | ex])
        assert_passes(output, status)
        results = test_results(output)
        expected = for rel <- ex, line <- koan_lines(rel), do: {rel, line}
        assert Enum.reject(expected, &(results[&1] == "ok")) == []
      end

      if ts != [] do
        {output, status, records} = npm_verify(ts)
        assert status == 0, output_tail(output)
        refute output =~ "warning:", output_tail(output)

        for rel <- ts do
          assert record_lines(records, rel) == ts_koan_lines(rel), output_tail(output)
        end

        assert Enum.reject(records, &(&1["status"] == "ok")) == []
      end
    end
  end

  defp assert_ex_chapter_fails(nn, rel) do
    {output, _} = mix_verify(["test", "--warnings-as-errors", rel])
    refute output =~ "warning:", output_tail(output)

    expected = for line <- koan_lines(rel), do: {rel, line}
    results = test_results(output)
    blanks = blank_results(output)
    assert expected != [], "no koans in #{rel}"

    wrong =
      for key <- expected,
          not own_blank?(nn, rel, {results[key], blanks[key]}),
          do: {key, results[key], blanks[key]}

    assert wrong == [],
           "koans not failing as a chapter #{nn} blank:\n#{inspect(wrong)}\n" <>
             output_tail(output)
  end

  defp assert_ts_chapter_fails(nn, rel) do
    {output, _status, records} = npm_verify([rel])
    expected = ts_koan_lines(rel)
    assert expected != [], "no koans in #{rel}"
    assert record_lines(records, rel) == expected, output_tail(output)

    wrong = for %{"file" => ^rel} = record <- records, not own_ts_blank?(nn, record), do: record

    assert wrong == [],
           "koans not failing as a chapter #{nn} blank:\n#{inspect(wrong)}\n" <>
             output_tail(output)
  end

  describe "checkpoints" do
    @tag :after_chapter_08
    test "chapter_08_creates_a_board_and_mounts_its_page" do
      assert_checkpoint_test(8, "08_board_page_test.exs")
    end

    @tag :after_chapter_10
    test "chapter_10_keeps_an_added_shape_for_the_next_view" do
      assert_checkpoint_test(10, "10_shapes_kept_test.exs")
    end

    @tag :after_chapter_12
    test "chapter_12_pushes_an_add_to_another_view_and_lists_both_people" do
      assert_checkpoint_test(12, "12_two_viewers_test.exs")
    end
  end

  defp assert_checkpoint_test(upto, file) do
    :ok = Chapters.build(upto)

    {output, status} =
      mix(["test", Path.join(@checkpoints, file)], [
        {"KOANS_LIB", "_verify/lib"},
        {"MIX_TEST_PARTITION", "verify"},
        {"MIX_ENV", "test"},
        {"KOANS_DIR", @checkpoints}
      ])

    assert status == 0, output_tail(output)
    assert output =~ "1 test, 0 failures", output_tail(output)
  end

  defp migrate_and_run(script) do
    ~w(do ecto.create --quiet + ecto.migrate --quiet + run) ++ [Path.join(@checkpoints, script)]
  end

  defp mix_dev(args) do
    mix(args, [
      {"MIX_ENV", "dev"},
      {"KOANS_LIB", "_verify/lib"},
      {"MIX_TEST_PARTITION", nil},
      {"KOANS_DIR", nil}
    ])
  end

  test "boots_with_every_blank" do
    :ok = Chapters.build(-1)
    {output, status} = mix_dev(["compile", "--warnings-as-errors"])
    assert status == 0, output_tail(output)

    assert_types_clean(".")

    {output, status} = mix_dev(migrate_and_run("name_page.exs"))
    assert status == 0, output_tail(output)
    assert output =~ ~r/^CHECKPOINT 200$/m, output_tail(output)
  end

  test "reset_survives_broken_lib" do
    hello = Path.join(root(), "lib/easel/hello.ex")
    ts_hello = Path.join(root(), "assets/js/hello.ts")
    koan = hd(koan_files("test/koans"))
    originals = Map.new([hello, ts_hello, koan], &{&1, File.read!(&1)})
    backup = Path.join(root(), ".koans")
    had_backup? = File.exists?(backup)

    on_exit(fn ->
      Enum.each(originals, fn {path, text} -> File.write!(path, text) end)
      unless had_backup?, do: File.rm_rf!(backup)
    end)

    blank = ~s[__("00: say hello")]
    assert originals[hello] =~ blank
    File.write!(hello, String.replace(originals[hello], blank, ~s["hello " <> (]))

    ts_blank = ~s[__blank("00: greet");]
    assert originals[ts_hello] =~ ts_blank
    File.write!(ts_hello, String.replace(originals[ts_hello], ts_blank, ~s[return "hello " + (]))

    {output, status} =
      mix(["koans.reset", "00"], [
        {"MIX_ENV", "dev"},
        {"KOANS_LIB", nil},
        {"MIX_TEST_PARTITION", nil}
      ])

    assert status == 0, output
    assert output =~ ~r/^reset chapter 00: .*lib\/easel\/hello\.ex/m
    assert output =~ ~r/^reset chapter 00: .*assets\/js\/hello\.ts/m
    refute output =~ "Generated easel app"
    refute output =~ "Compilation error"
    assert File.read!(hello) == expected_learner("lib/easel/hello.ex")
    assert File.read!(ts_hello) == expected_learner("assets/js/hello.ts")
  end

  defp expected_learner(rel) do
    file = Enum.find(Project.source_files(root()), &(&1.rel == rel))
    Project.learner_text(file, File.read!(file.path))
  end

  test "solutions_pass" do
    {output, status} =
      mix(["koans"], [
        {"KOANS_LIB", "solutions/lib"},
        {"MIX_TEST_PARTITION", nil},
        {"MIX_ENV", "test"},
        {"KOANS_DIR", nil},
        {"KOANS_TS_DIR", nil},
        {"KOANS_VERIFY", nil}
      ])

    assert status == 0, output_tail(output)
    assert output =~ "Enlightenment", output_tail(output)
  end

  test "app_suites_pass_on_solutions" do
    {output, status} =
      mix(["test"], [
        {"KOANS_LIB", "solutions/lib"},
        {"MIX_TEST_PARTITION", "app"},
        {"MIX_ENV", "test"},
        {"KOANS_DIR", nil}
      ])

    assert status == 0, output_tail(output)

    {output, status} = npm(["run", "test:app"], [{"KOANS_LIB", "solutions/lib"}])
    assert status == 0, output_tail(output)
  end

  test "mirror" do
    learner = koan_files("test/koans")
    solutions = koan_files("solutions/test/koans")
    assert learner != []
    assert Enum.map(learner, &Path.basename/1) == Enum.map(solutions, &Path.basename/1)

    for {l, s} <- Enum.zip(learner, solutions) do
      assert length(koan_lines(l)) == length(koan_lines(s)), Path.basename(l)
      assert module_names(l) == module_names(s), Path.basename(l)
    end

    ts_learner = ts_koan_files("assets/koans")
    ts_solutions = ts_koan_files("solutions/assets/koans")
    assert ts_learner != []
    assert Enum.map(ts_learner, &Path.basename/1) == Enum.map(ts_solutions, &Path.basename/1)

    for {l, s} <- Enum.zip(ts_learner, ts_solutions) do
      assert ts_koan_lines(l) == ts_koan_lines(s), Path.basename(l)
    end

    for dir <- ~w(lib test/support assets/js assets/svelte assets/test assets/koans) do
      assert tree(dir) == tree("solutions/" <> dir), dir
    end
  end

  defp module_names(path),
    do: ~r/^\s*defmodule\s+([\w.]+)/m |> Regex.scan(File.read!(path)) |> Enum.map(&List.last/1)

  defp tree(dir) do
    base = Path.join(root(), dir)

    base
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.map(&Path.relative_to(&1, base))
  end

  test "regenerating_changes_nothing" do
    files = Enum.filter(Project.source_files(root()), &generated_here?/1)
    assert files != []

    for file <- files, side <- [:learner, :solutions] do
      target = Path.join(Project.side_root(root(), side), file.rel)
      assert Project.content(file, side) == File.read!(target), Path.relative_to(target, root())
    end
  end

  defp generated_here?(%{rel: rel}) do
    case Project.chapter_of(rel) do
      nil -> true
      nn -> not Project.koan_file?(rel) or nn in chapters()
    end
  end

  test "app_code_is_formatted_in_every_generated_tree" do
    files =
      for file <- Project.source_files(root()),
          not Project.koan_file?(file.rel),
          Path.extname(file.rel) in ~w(.ex .exs .heex),
          do: file

    assert files != []

    unformatted =
      for file <- files,
          text <- generated_texts(file),
          {format, _} = Mix.Tasks.Format.formatter_for_file(file.rel),
          format.(text) != text,
          uniq: true,
          do: file.rel

    assert unformatted == []
  end

  test "mix_format_leaves_koan_files_alone" do
    {formatter, _} = Code.eval_file(Path.join(root(), ".formatter.exs"))

    formatted =
      for pattern <- formatter[:inputs],
          path <- Path.wildcard(Path.join(root(), pattern), match_dot: true),
          do: Path.relative_to(path, root())

    assert Enum.any?(formatted, &String.starts_with?(&1, "test/easel/"))
    assert File.exists?(Path.join(root(), "test/koans/00_about_koans_test.exs"))
    assert Enum.filter(formatted, &String.starts_with?(&1, "test/koans/")) == []

    {output, status} = mix(["format", "--check-formatted"], [{"MIX_ENV", "test"}])
    assert status == 0, output_tail(output)
  end

  defp generated_texts(file) do
    source = File.read!(file.path)

    partials =
      for nn <- all_chapters(),
          do: Gen.partial(source, String.to_integer(nn), Project.render_opts(file))

    Enum.uniq([Project.content(file, :learner), Project.content(file, :solutions) | partials])
  end

  test "source_rules_hold" do
    assert Project.check(root()) == []
  end

  defp koan_texts(paths), do: for(path <- paths, do: {chapter(path), File.read!(path)})

  defp source_texts(extensions) do
    for file <- Project.source_files(root()),
        not Project.koan_file?(file.rel),
        Path.extname(file.rel) in extensions,
        do: {file.rel, File.read!(file.path)}
  end

  test "api_calls_are_taught" do
    ex_selected = koan_texts(selected_files("source/test/koans"))
    ts_selected = koan_texts(selected_ts_files("source/assets/koans"))
    names = Enum.uniq(Enum.map(ex_selected ++ ts_selected, &elem(&1, 0)))
    assert names != []
    wanted = ApiCheck.context_chapters(all_chapters(), names)

    ex_context =
      for path <- koan_files("source/test/koans"),
          chapter(path) in wanted,
          do: {chapter(path), File.read!(path)}

    ex_missing =
      ApiCheck.missing(ex_selected, ex_context, source_texts(~w(.ex .exs)))
      |> Enum.filter(&(String.slice(&1, 0, 2) in names))

    assert ex_missing == []

    upto = Enum.max(names)

    lessons =
      for path <- koan_files("source/test/koans") ++ ts_koan_files("source/assets/koans"),
          chapter(path) <= upto,
          do: {chapter(path), File.read!(path)}

    ts_missing =
      lessons
      |> Ts.ApiCheck.missing(source_texts(~w(.ts .js .svelte)))
      |> Enum.filter(&(String.slice(&1, 0, 2) in names))

    assert ts_missing == []
  end

  defp lesson_of(path) do
    text = File.read!(path)
    if Path.extname(path) == ".exs", do: ApiCheck.lesson(text), else: Ts.ApiCheck.lesson(text)
  end

  defp lesson_problems(path) do
    text = File.read!(path)

    if Path.extname(path) == ".exs",
      do: ApiCheck.lesson_problems(ApiCheck.lesson(text)),
      else: Ts.ApiCheck.lesson_problems(text)
  end

  defp selected_koan_sources,
    do: selected_files("source/test/koans") ++ selected_ts_files("source/assets/koans")

  test "lessons_have_api_and_picture_lines" do
    paths = selected_koan_sources()
    assert paths != []

    for path <- paths do
      lesson = lesson_of(path)
      name = Path.basename(path)
      assert lesson_problems(path) == [], name
      assert touched_files(lesson) != [], "#{name}: no Files this chapter touches list"

      for touched <- touched_files(lesson) do
        assert File.exists?(Path.join([root(), "source", touched])), "#{name}: #{touched}"
      end
    end
  end

  test "lesson_footer_examples_point_at_real_lines" do
    for path <- selected_koan_sources() do
      lesson = lesson_of(path)
      examples = Regex.scan(~r/(Write|Exercised by):\s+(\S+):(\d+)/, lesson)
      assert examples != [], "#{Path.basename(path)}: no footer example"

      for [_, label, file, line] <- examples do
        text = learner_line(file, String.to_integer(line))
        place = "#{Path.basename(path)}: #{label} #{file}:#{line} is #{inspect(text)}"

        case {label, Path.extname(file)} do
          {"Write", ".ex"} -> assert text =~ ~s[__("], place
          {"Write", _} -> assert text =~ ~s[__blank("], place
          {"Exercised by", ".exs"} -> assert text =~ ~r/^\s*koan\s+"/, place
          {"Exercised by", _} -> assert text =~ ~r/^test\("/, place
        end
      end
    end
  end

  defp learner_line(file, line) do
    root() |> Path.join(file) |> File.read!() |> String.split("\n") |> Enum.at(line - 1, "")
  end

  defp touched_files(lesson) do
    lesson
    |> String.split("\n")
    |> Enum.drop_while(&(String.trim(&1) != "Files this chapter touches"))
    |> Enum.drop(1)
    |> Enum.take_while(&String.match?(&1, ~r/^\s+- /))
    |> Enum.map(&(Regex.run(~r/^\s+- ([^\s:]+)/, &1) |> List.last()))
  end

  test "koans_compile_without_warnings" do
    :ok = Chapters.build(-1)
    {output, status} = mix_verify(["compile", "--warnings-as-errors"])
    assert status == 0, output_tail(output)

    rels = Enum.map(selected_files("_verify/test/koans"), &rel/1)
    {output, status} = mix_verify(["test", "--warnings-as-errors", "--exclude", "test" | rels])
    assert status == 0, output_tail(output)
    refute output =~ "warning:", output_tail(output)
  end

  test "a_mix_run_waits_out_a_source_mtime_in_the_future" do
    :ok = Chapters.build(-1)
    source = Path.join(root(), "_verify/lib/easel_web/live/board_live.ex")
    ahead = System.os_time(:second) + 3
    File.touch!(source, ahead)
    assert File.stat!(source, time: :posix).mtime == ahead

    {output, status} = mix_verify(["compile"])
    assert status == 0, output_tail(output)
    refute output =~ "set to the future", output_tail(output)
  end

  test "nearest_line_runs_one_koan" do
    :ok = Chapters.build(-1)
    paths = selected_files("_verify/test/koans")
    assert paths != []

    for path <- paths do
      relative = rel(path)
      koan_line = path |> koan_lines() |> List.last()
      {output, _} = mix_verify(["test", "#{relative}:#{koan_line + 1}"])
      assert Map.keys(test_results(output)) == [{relative, koan_line}], output_tail(output)
    end
  end

  test "nearest_name_runs_one_ts_koan" do
    :ok = Chapters.build(-1)
    paths = selected_ts_files("_verify/assets/koans")
    assert paths != []

    for path <- paths do
      relative = rel(path)
      koan_line = path |> ts_koan_lines() |> List.last()

      [_, meditation] =
        Regex.run(~r/^test\("((?:[^"\\]|\\.)*)",/, learner_line(relative, koan_line))

      {output, _status, records} = npm_verify([relative], ["-t", meditation])

      assert Enum.map(records, &{&1["file"], &1["line"]}) == [{relative, koan_line}],
             output_tail(output)
    end

    # A file may hold one koan, so also show that a name matching none runs none.
    {output, _status, records} = npm_verify([rel(hd(paths))], ["-t", "no koan has this name"])
    assert records == [], output_tail(output)
  end
end
