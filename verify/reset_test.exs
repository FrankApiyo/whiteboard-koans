defmodule Verify.ResetTest do
  use ExUnit.Case, async: false

  alias Koans.Gen

  defp module_source(name) do
    """
    defmodule #{name} do
      def seven(x) do
        # >>> answer 07: seven
        x + 1
        # <<<
      end

      def nine(x) do
        # >>> answer 09: nine
        x * 2
        # <<<
      end

      def untouched(x), do: x
    end
    """
  end

  defp fill(text, tag, code) do
    String.replace(text, "    __(\"#{tag}\")", code)
  end

  defp compile!(text) do
    path = Path.join(System.tmp_dir!(), "reset_#{System.unique_integer([:positive])}.ex")
    File.write!(path, text)

    try do
      {:ok, modules, diagnostics} =
        Kernel.ParallelCompiler.compile([path], return_diagnostics: true)

      Enum.each(modules, &(:code.purge(&1) && :code.delete(&1)))
      diagnostics.compile_warnings ++ diagnostics.runtime_warnings
    after
      File.rm(path)
    end
  end

  test "reset_reblanks_only_the_chapter" do
    name = "Verify.Reset#{System.unique_integer([:positive])}"
    source = module_source(name)
    learner = Gen.learner(source)

    filled =
      learner
      |> fill("07: seven", "    y = x\n    y + 100")
      |> fill("09: nine", "    z = [x, x]\n    Enum.sum(z) + 7")

    assert filled =~ "y + 100"
    assert filled =~ "Enum.sum(z) + 7"

    reset = Gen.reblank(filled, source, "07")

    assert reset == fill(learner, "09: nine", "    z = [x, x]\n    Enum.sum(z) + 7")
    refute reset =~ "y + 100"
    assert reset =~ ~S|__("07: seven")|
    assert reset =~ "    z = [x, x]\n    Enum.sum(z) + 7\n    # <<< 09\n"
    assert compile!(reset) == []
  end

  test "reblank_puts_warn_false_back_on_imports_of_a_filled_file" do
    source =
      "defmodule Verify.Warn do\n  import Enum\n  def f(x) do\n    # >>> answer 07: f\n    map(x, & &1)\n    # <<<\n  end\nend\n"

    filled =
      source
      |> Gen.learner(imports: false, chapter: "07")
      |> fill("07: f", "    map(x, & &1)")
      |> String.replace("import Enum, warn: false", "import Enum")

    assert filled =~ "  import Enum\n"
    reset = Gen.reblank(filled, source, "07")
    assert reset =~ "  import Enum, warn: false\n"
    assert reset == Gen.learner(source, imports: false, chapter: "07")
  end

  test "the_compile_helper_can_fail_on_a_warning" do
    name = "Verify.Warn#{System.unique_integer([:positive])}"
    assert compile!("defmodule #{name} do\n  def f(x) do\n    y = x\n    1\n  end\nend\n") != []
  end

  test "reblank_works_when_the_chapter_code_does_not_compile" do
    name = "Verify.Broken#{System.unique_integer([:positive])}"
    source = module_source(name)
    broken = source |> Gen.learner() |> fill("07: seven", "    this is not ((( elixir")
    assert Gen.reblank(broken, source, "07") == Gen.learner(source)
  end

  test "reblank_keeps_edits_outside_markers_byte_for_byte" do
    source = module_source("Verify.Outside")
    learner = Gen.learner(source)

    edited =
      String.replace(learner, "def untouched(x), do: x", "def untouched(x),   do: x # mine")

    assert Gen.reblank(edited, source, "09") == edited
  end

  test "reblank_after_the_stub_line_was_deleted_and_clauses_written_in_its_place" do
    source =
      "defmodule Verify.Stub do\n  # >>> answer 07: handler | stub: def handle(msg)\n" <>
        "  def handle(:a), do: 1\n  def handle(:b), do: 2\n  # <<<\nend\n"

    learner = Gen.learner(source)
    assert learner =~ "  def handle(msg), do: __(\"07: handler\")\n"

    written =
      String.replace(
        learner,
        "  def handle(msg), do: __(\"07: handler\")\n",
        "  def handle(:a), do: 10\n  def handle(:b), do: 20\n  def handle(_), do: 30\n"
      )

    assert Gen.reblank(written, source, "07") == learner
  end

  test "reblank_follows_a_changed_region_indentation" do
    source = module_source("Verify.Indent")
    learner = Gen.learner(source)

    indented =
      learner
      |> String.replace(
        "    # >>> 07\n    __(\"07: seven\")\n    # <<< 07\n",
        "        # >>> 07\n        y = 1\n        y\n        # <<< 07\n"
      )

    reset = Gen.reblank(indented, source, "07")
    assert reset =~ "        # >>> 07\n        __(\"07: seven\")\n        # <<< 07\n"
    refute reset =~ "y = 1"
  end

  test "reblank_keeps_the_line_endings_of_a_crlf_file" do
    source = module_source("Verify.Crlf")
    crlf = source |> Gen.learner() |> String.replace("\n", "\r\n")
    filled = String.replace(crlf, "    __(\"07: seven\")\r\n", "    y = 5\r\n    y\r\n")

    reset = Gen.reblank(filled, source, "07")

    assert reset == crlf
    assert reset =~ "    __(\"07: seven\")\r\n"
    refute String.replace(reset, "\r\n", "") =~ "\n"
  end

  test "reblank_restores_defaulted_blanks" do
    source =
      "defmodule Verify.Default do\n  def f(socket) do\n    # >>> answer 14: subscribe | default: socket\n" <>
        "    Phoenix.PubSub.subscribe(Q.PubSub, \"t\")\n    socket\n    # <<<\n  end\nend\n"

    learner = Gen.learner(source)
    assert learner =~ ~S|    __("14: subscribe", socket)|
    filled = String.replace(learner, ~S|    __("14: subscribe", socket)|, "    :done")
    assert Gen.reblank(filled, source, "14") == learner
    assert compile!(learner) == []
  end

  test "reblank_leaves_a_file_without_the_chapter_alone" do
    source = module_source("Verify.Absent")
    learner = Gen.learner(source)
    assert Gen.reblank(learner, source, "12") == learner
  end

  test "a_deleted_close_marker_raises_naming_the_line" do
    source = module_source("Verify.Deleted")
    learner = Gen.learner(source)
    damaged = String.replace(learner, "    # <<< 07\n", "")
    assert damaged != learner

    assert_raise ArgumentError, ~r/line \d+.*# >>> 07/, fn ->
      Gen.reblank(damaged, source, "07")
    end

    [before_open | _] = String.split(damaged, "# >>> 07")
    line = length(String.split(before_open, "\n"))
    assert_raise ArgumentError, ~r/line #{line}\b/, fn -> Gen.reblank(damaged, source, "07") end
  end

  test "a_deleted_open_marker_raises_naming_the_line" do
    source = module_source("Verify.DeletedOpen")
    damaged = source |> Gen.learner() |> String.replace("    # >>> 07\n", "")

    assert_raise ArgumentError, ~r/line \d+.*# <<< 07/, fn ->
      Gen.reblank(damaged, source, "07")
    end
  end

  test "a_region_whose_markers_were_both_deleted_is_named_with_its_place" do
    source =
      "defmodule Verify.Two do\n  def seven(x) do\n    # >>> answer 07: seven\n    x + 1\n    # <<<\n  end\n\n" <>
        "  def eight(x) do\n    # >>> answer 07: eight\n    x + 8\n    # <<<\n  end\nend\n"

    learner = Gen.learner(source)
    region = "    # >>> 07\n    __(\"07: eight\")\n    # <<< 07\n"
    assert learner =~ region
    damaged = String.replace(learner, region, "    x * 8\n")

    lines = String.split(damaged, "\n")
    line = Enum.find_index(lines, &(&1 == "  def eight(x) do")) + 1

    message =
      Exception.message(assert_raise(ArgumentError, fn -> Gen.reblank(damaged, source, "07") end))

    assert message =~ "chapter 07"
    assert message =~ ~s("07: eight")
    assert message =~ "after line #{line}"
    refute message =~ ~s("07: seven")
  end

  test "a_region_count_mismatch_raises" do
    source = module_source("Verify.Count")
    two = module_source("Verify.Count") <> "\n" <> String.replace(source, "Count", "CountTwo")

    assert_raise ArgumentError, ~r/chapter 07/, fn ->
      Gen.reblank(Gen.learner(source), two, "07")
    end
  end

  test "heex_regions_are_reblanked_too" do
    source = "<p>\n  <%!-- >>> answer 13: preview --%>\n  {@note.body}\n  <%!-- <<< --%>\n</p>\n"
    learner = Gen.learner(source, imports: false)
    filled = String.replace(learner, ~S|{__("13: preview")}|, "{String.upcase(@x)}")
    assert Gen.reblank(filled, source, "13") == learner
  end

  describe "mix koans.reset and mix koans.cold" do
    setup do
      root = Path.join(System.tmp_dir!(), "koans_reset_#{System.unique_integer([:positive])}")
      File.mkdir_p!(Path.join(root, "source/test/koans"))
      File.mkdir_p!(Path.join(root, "source/lib"))

      File.write!(Path.join(root, "source/lib/m.ex"), module_source("Reset.M"))

      for n <- ["07", "09"] do
        File.write!(Path.join(root, "source/test/koans/#{n}_t_test.exs"), """
        defmodule Koans.Ch#{n}.T do
          use Koans

          koan "Implement it. 1. Do it. Ok." do
            # >>> answer
            x = 1
            # <<<
            assert x == _a(1)
          end
        end
        """)
      end

      out = ExUnit.CaptureIO.capture_io(fn -> Mix.Tasks.Koans.Gen.run(["--root", root]) end)
      assert out =~ "wrote"
      on_exit(fn -> File.rm_rf!(root) end)
      %{root: root}
    end

    defp run_task(task, args) do
      ExUnit.CaptureIO.capture_io(fn -> task.run(args) end)
    end

    test "reset NN reblanks lib and restores the koan file", %{root: root} do
      lib = Path.join(root, "lib/m.ex")
      koan7 = Path.join(root, "test/koans/07_t_test.exs")
      koan9 = Path.join(root, "test/koans/09_t_test.exs")

      File.write!(
        lib,
        lib |> File.read!() |> fill("07: seven", "    x - 1") |> fill("09: nine", "    x")
      )

      restored7 = File.read!(koan7)
      File.write!(koan7, "# learner scribbles\n")
      File.write!(koan9, "# learner scribbles\n")

      output = run_task(Mix.Tasks.Koans.Reset, ["07", "--root", root])

      assert File.read!(lib) =~ ~S|__("07: seven")|
      assert File.read!(lib) =~ "    x\n    # <<< 09"
      assert File.read!(koan7) == restored7
      assert restored7 =~ "# >>> 07\n    __()\n    # <<< 07"
      assert File.read!(koan9) == "# learner scribbles\n"
      assert output =~ "lib/m.ex"
      assert output =~ "test/koans/07_t_test.exs"
      refute output =~ "git checkout"
    end

    test "reset NN saves the files it overwrites and names the backup", %{root: root} do
      lib = Path.join(root, "lib/m.ex")
      filled = lib |> File.read!() |> fill("07: seven", "    x - 1")
      File.write!(lib, filled)
      File.write!(Path.join(root, "test/koans/07_t_test.exs"), "# my answers\n")
      backup = Path.join(root, ".koans/last-reset")

      output = run_task(Mix.Tasks.Koans.Reset, ["07", "--root", root])

      assert File.read!(Path.join(backup, "lib/m.ex")) == filled
      assert File.read!(Path.join(backup, "test/koans/07_t_test.exs")) == "# my answers\n"
      assert output =~ ".koans/last-reset"
      refute output =~ "git checkout"
    end

    test "each reset replaces the last backup, and a reset that changes nothing keeps it", %{
      root: root
    } do
      backup = Path.join(root, ".koans/last-reset")
      File.write!(Path.join(root, "test/koans/07_t_test.exs"), "# seven\n")
      run_task(Mix.Tasks.Koans.Reset, ["07", "--root", root])
      assert File.exists?(Path.join(backup, "test/koans/07_t_test.exs"))

      File.write!(Path.join(root, "test/koans/09_t_test.exs"), "# nine\n")
      run_task(Mix.Tasks.Koans.Reset, ["09", "--root", root])

      assert File.read!(Path.join(backup, "test/koans/09_t_test.exs")) == "# nine\n"
      refute File.exists?(Path.join(backup, "test/koans/07_t_test.exs"))

      output = run_task(Mix.Tasks.Koans.Reset, ["09", "--root", root])
      assert output =~ "already blank"
      assert File.read!(Path.join(backup, "test/koans/09_t_test.exs")) == "# nine\n"
    end

    test "reset all regenerates every learner file", %{root: root} do
      lib = Path.join(root, "lib/m.ex")
      pristine = File.read!(lib)
      File.write!(lib, "garbage(((\n")
      File.write!(Path.join(root, "test/koans/09_t_test.exs"), "garbage\n")

      output = run_task(Mix.Tasks.Koans.Reset, ["all", "--root", root])

      assert File.read!(lib) == pristine
      assert File.read!(Path.join(root, "test/koans/09_t_test.exs")) =~ "# >>> 09"
      assert File.read!(Path.join(root, ".koans/last-reset/lib/m.ex")) == "garbage(((\n"
      assert output =~ ".koans/last-reset"
      refute output =~ "git checkout"
    end

    test "reset writes nothing when any file has broken markers", %{root: root} do
      File.write!(Path.join(root, "source/lib/a.ex"), module_source("Reset.A"))
      File.write!(Path.join(root, "source/lib/b.ex"), module_source("Reset.B"))
      run_task(Mix.Tasks.Koans.Gen, ["--root", root])
      a = Path.join(root, "lib/a.ex")
      b = Path.join(root, "lib/b.ex")
      koan = Path.join(root, "test/koans/07_t_test.exs")

      a_filled = a |> File.read!() |> fill("07: seven", "    1")
      File.write!(a, a_filled)
      File.write!(b, b |> File.read!() |> String.replace("    # <<< 07\n", ""))
      File.write!(koan, "# scribble\n")
      b_broken = File.read!(b)

      error =
        assert_raise Mix.Error, ~r/lib\/b.ex: line \d+/, fn ->
          Mix.Tasks.Koans.Reset.run(["07", "--root", root])
        end

      assert error.message =~ "# >>> 07"
      assert error.message =~ "# <<< 07"
      assert error.message =~ "mix koans.reset 07 again"
      refute File.exists?(Path.join(root, ".koans/last-reset"))
      assert File.read!(a) == a_filled
      assert File.read!(b) == b_broken
      assert File.read!(koan) == "# scribble\n"
    end

    test "cold reports broken markers instead of crashing", %{root: root} do
      lib = Path.join(root, "lib/m.ex")
      File.write!(lib, lib |> File.read!() |> String.replace("    # <<< 07\n", ""))
      koan = Path.join(root, "test/koans/07_t_test.exs")
      before = File.read!(koan)

      assert_raise Mix.Error, ~r/lib\/m.ex: line \d+/, fn ->
        Mix.Tasks.Koans.Cold.run(["07", "--root", root])
      end

      assert File.read!(koan) == before
    end

    test "reset all names the files it changed", %{root: root} do
      File.write!(Path.join(root, "lib/m.ex"), "garbage\n")
      output = run_task(Mix.Tasks.Koans.Reset, ["all", "--root", root])
      assert output =~ "regenerated: lib/m.ex\n"
      refute output =~ "test/koans"
    end

    test "reset of an unknown chapter raises", %{root: root} do
      assert_raise Mix.Error, ~r/no chapter 42/, fn ->
        Mix.Tasks.Koans.Reset.run(["42", "--root", root])
      end
    end

    test "reset without source raises a clear message" do
      empty = Path.join(System.tmp_dir!(), "koans_nosrc_#{System.unique_integer([:positive])}")
      File.mkdir_p!(empty)
      on_exit(fn -> File.rm_rf!(empty) end)

      assert_raise Mix.Error, ~r/no source\/ directory/, fn ->
        Mix.Tasks.Koans.Reset.run(["all", "--root", empty])
      end
    end

    test "cold resets the chapter and strips the steps", %{root: root} do
      file = Path.join(root, "test/koans/07_t_test.exs")
      assert File.read!(file) =~ " 1. Do it."

      output = run_task(Mix.Tasks.Koans.Cold, ["07", "--root", root])

      refute File.read!(file) =~ " 1. "
      assert File.read!(file) =~ ~S|koan "Implement it." do|
      assert File.read!(file) =~ "# >>> 07\n    __()\n    # <<< 07"

      assert output =~
               "test/koans/07_t_test.exs is cold: meditations now give the behaviour only."

      assert output =~ ".koans/last-reset"
      refute output =~ "git checkout"
    end

    test "a chapter with nothing to strip is left as it is", %{root: root} do
      source = Path.join(root, "source/test/koans/07_t_test.exs")
      File.write!(source, File.read!(source) |> String.replace(" 1. Do it. Ok.", ""))
      run_task(Mix.Tasks.Koans.Gen, ["--root", root])
      file = Path.join(root, "test/koans/07_t_test.exs")
      typed = File.read!(file) <> "# typed by the learner\n"
      File.write!(file, typed)

      output = run_task(Mix.Tasks.Koans.Cold, ["07", "--root", root])

      assert File.read!(file) == typed
      assert output =~ "test/koans/07_t_test.exs has nothing to strip; it is left as it is."
      refute output =~ "is cold"
    end

    test "cold of an unknown chapter raises", %{root: root} do
      assert_raise Mix.Error, ~r/no chapter 99/, fn ->
        Mix.Tasks.Koans.Cold.run(["99", "--root", root])
      end
    end

    test "gen without source raises a clear message" do
      empty = Path.join(System.tmp_dir!(), "koans_nosrc2_#{System.unique_integer([:positive])}")
      File.mkdir_p!(empty)
      on_exit(fn -> File.rm_rf!(empty) end)

      assert_raise Mix.Error, ~r/no source\/ directory/, fn ->
        Mix.Tasks.Koans.Gen.run(["--root", empty])
      end
    end
  end
end
