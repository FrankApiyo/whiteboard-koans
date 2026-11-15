defmodule Verify.ApiCheckTest do
  use ExUnit.Case, async: false

  alias Koans.ApiCheck

  defp chapter(doc, body) do
    ~s'''
    defmodule Koans.ChX.Own do
      def run, do: 1
    end

    defmodule Koans.ChX.T do
      use Koans
      @moduledoc ~S"""
      #{doc}
      """
      #{body}
    end
    '''
  end

  test "flags_a_remote_call_the_lessons_never_mention" do
    source = chapter("API you'll use: Enum.map", "def a, do: _a(Enum.sum([1]))")
    assert ApiCheck.missing([{"01", source}]) == ["01: Enum.sum not in this or an earlier lesson"]
  end

  test "an_earlier_lesson_teaches_the_call_but_a_later_one_does_not" do
    taught = chapter("Enum.sum", "")
    uses = chapter("none", "def a, do: _a(Enum.sum([1]))")
    assert ApiCheck.missing([{"01", taught}, {"02", uses}]) == []

    assert ApiCheck.missing([{"01", uses}, {"02", taught}]) == [
             "01: Enum.sum not in this or an earlier lesson"
           ]
  end

  test "block_calls_aliases_erlang_and_exemptions" do
    body = """
    alias Foo.Bar, as: B
    def a do
      # >>> answer
      :queue.in(1, :queue.new()) |> B.go() |> Koans.Ch00.Own.run() |> Kernel.+(1)
      # <<<
    end
    """

    assert ApiCheck.missing([{"01", chapter("none", body)}]) ==
             [
               "01: :queue.in not in this or an earlier lesson",
               "01: :queue.new not in this or an earlier lesson",
               "01: Foo.Bar.go not in this or an earlier lesson"
             ]
  end

  test "calls_outside_answers_are_ignored" do
    assert ApiCheck.missing([{"01", chapter("none", "def a, do: Enum.sum([1])")}]) == []
  end

  test "a_moduledoc_false_helper_above_the_test_module_does_not_hide_the_lesson" do
    helper = "defmodule Helper do\n  @moduledoc false\nend\n"
    source = helper <> chapter("Enum.sum", "def a, do: _a(Enum.sum([1]))")
    assert ApiCheck.missing([{"01", source}]) == []
  end

  test "context_lessons_teach_but_are_not_checked_and_broken_ones_are_skipped" do
    uses = chapter("none", "def a, do: _a(Enum.sum([1]))")
    taught = chapter("Enum.sum", "")
    assert ApiCheck.missing([{"05", uses}], [{"02", taught}]) == []
    assert ApiCheck.missing([{"05", uses}], [{"02", "defmodule Half do"}]) != []
  end

  test "a_longer_name_does_not_teach_a_shorter_one" do
    uses = chapter("none", "def a, do: _a(Enum.reduce([1], 0, & &1))")
    taught = chapter("Enum.reduce_while", "")

    assert ApiCheck.missing([{"01", taught}, {"02", uses}]) ==
             ["02: Enum.reduce not in this or an earlier lesson"]
  end

  test "context_is_every_unselected_chapter_below_the_highest_selected" do
    all = ~w(00 01 02 03 04 05 06)
    assert ApiCheck.context_chapters(all, ~w(02 05)) == ~w(00 01 03 04)
  end

  defp lesson(body_lines, entries, picture_first? \\ false) do
    lesson_with(body_lines, Enum.map(1..entries, &"  - F.f#{&1}/0: x"), picture_first?)
  end

  defp lesson_with(body_lines, entry_lines, picture_first? \\ false) do
    body = Enum.map_join(1..body_lines, "\n", &"line #{&1}")
    api = Enum.join(["API you'll use" | entry_lines], "\n")
    picture = "Picture: none"

    if picture_first?,
      do: Enum.join([body, "", picture, api], "\n"),
      else: Enum.join([body, "", api, "", picture], "\n")
  end

  test "lesson_body_counts_up_to_the_api_line_only" do
    assert ApiCheck.lesson_problems(lesson(30, 12)) == []
    assert [problem] = ApiCheck.lesson_problems(lesson(31, 12))
    assert problem =~ "31 lines"
    assert [_] = ApiCheck.lesson_problems(lesson(9, 1))
    assert [_] = ApiCheck.lesson_problems(lesson(12, 16))

    assert ApiCheck.lesson_problems(lesson(12, 3, true)) == [
             "Picture: comes before API you'll use"
           ]
  end

  defp undashed(n), do: Enum.map(1..n, &"    Enum.f#{&1}/2   Enum.f#{&1}([1], & &1)  #=> [1]")

  test "undashed_entries_count_toward_the_limit" do
    assert ApiCheck.lesson_problems(lesson_with(12, undashed(15))) == []

    assert ApiCheck.lesson_problems(lesson_with(12, undashed(16))) ==
             ["API list has 16 entries, want at most 15"]
  end

  test "a_wrapped_example_line_is_not_an_entry" do
    wrapped = undashed(15) ++ ["                    |> Enum.sum()  #=> 3", ""]
    assert ApiCheck.lesson_problems(lesson_with(12, wrapped)) == []
  end

  test "erlang_predicate_bang_and_bare_names_are_entries" do
    entries = [
      "    :queue.in/2   :queue.in(1, q)",
      "    Map.has_key?/2   Map.has_key?(%{a: 1}, :a)  #=> true",
      "  - match?/2: match?({:ok, _}, {:ok, 1})  #=> true",
      "    File.stream!/1   File.stream!(\"a.txt\")"
    ]

    assert ApiCheck.lesson_problems(lesson_with(12, entries ++ undashed(11))) == []

    assert ApiCheck.lesson_problems(lesson_with(12, entries ++ undashed(12))) ==
             ["API list has 16 entries, want at most 15"]
  end

  describe "answers in lib sources" do
    defp lib_source(body) do
      """
      defmodule Easel.Thing do
        alias Easel.Notes
        def run do
          # >>> answer 03: thing
          #{body}
          # <<<
        end
      end
      """
    end

    test "lib_answers_count_toward_their_tag_chapter" do
      lib = [{"source/lib/easel/thing.ex", lib_source("Enum.sum([1])")}]

      assert ApiCheck.missing([{"03", chapter("none", "")}], [], lib) ==
               ["03: Enum.sum not in this or an earlier lesson"]

      assert ApiCheck.missing(
               [{"02", chapter("Enum.sum", "")}, {"03", chapter("none", "")}],
               [],
               lib
             ) == []

      assert ApiCheck.missing(
               [{"03", chapter("none", "")}, {"04", chapter("Enum.sum", "")}],
               [],
               lib
             ) ==
               ["03: Enum.sum not in this or an earlier lesson"]
    end

    test "easel_modules_and_aliases_of_them_are_exempt" do
      lib = [
        {"source/lib/easel/thing.ex",
         lib_source("Notes.list() |> EaselWeb.Foo.bar() |> Easel.go()")}
      ]

      assert ApiCheck.missing([{"03", chapter("none", "")}], [], lib) == []
    end

    test "calls_outside_lib_answers_are_ignored" do
      text = "defmodule Easel.Thing do\n  def run, do: Enum.sum([1])\nend\n"

      assert ApiCheck.missing([{"03", chapter("none", "")}], [], [{"source/lib/a.ex", text}]) ==
               []
    end

    test "heex_files_are_skipped" do
      heex = "<%!-- >>> answer 03: a --%>\n{Enum.sum([1])}\n<%!-- <<< --%>\n"

      assert ApiCheck.missing([{"03", chapter("none", "")}], [], [
               {"source/lib/a.html.heex", heex}
             ]) == []
    end

    test "tagged_blocks_in_koan_files_use_the_tag_not_the_file" do
      body = "def a do\n  # >>> answer\n  Enum.sum([1])\n  # <<<\nend"

      assert ApiCheck.missing([{"01", chapter("none", body)}]) ==
               ["01: Enum.sum not in this or an earlier lesson"]
    end
  end
end
