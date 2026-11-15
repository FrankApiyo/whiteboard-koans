defmodule Verify.GenTest do
  use ExUnit.Case, async: true

  alias Koans.Gen

  @no_imports [imports: false]

  test "value blank becomes __ in learner and the value in solutions" do
    text = "    assert x == _a(3)\n"
    assert Gen.learner(text) == "    assert x == __\n"
    assert Gen.solutions(text) == "    assert x == 3\n"
  end

  test "a string holding a paren does not end the blank early" do
    text = ~S|assert s == _a("a)b")| <> "\n"
    assert Gen.learner(text) == "assert s == __\n"
    assert Gen.solutions(text) == ~S|assert s == "a)b"| <> "\n"
  end

  test "charlists, sigils and interpolation are skipped by the scanner" do
    text = ~S|assert [~r/)/, ')', "#{")"}"] == _a([~r/)/, ')', "#{")"}"])| <> "\n"
    assert Gen.learner(text) == ~S|assert [~r/)/, ')', "#{")"}"] == __| <> "\n"

    assert Gen.solutions(text) ==
             String.replace(text, "_a(", "") |> String.replace_suffix("])\n", "]\n")
  end

  test "question-mark calls and char literals inside a blank" do
    for expr <- ["Enum.empty?([])", "Map.has_key?(m, :a)", "?a", "[?(, ?)]"] do
      text = "assert x == _a(" <> expr <> ")\n"
      assert Gen.learner(text) == "assert x == __\n"
      assert Gen.solutions(text) == "assert x == " <> expr <> "\n"
    end
  end

  test "nested _a( raises naming the line" do
    assert_raise ArgumentError, ~r/line 2.*nested/, fn ->
      Gen.solutions("ok\nassert _a(a) == _a(_a(1))\n")
    end
  end

  test "a name ending in _a( is not a blank" do
    assert Gen.learner("foo_a(1)\n") == "foo_a(1)\n"
  end

  test "multi-line blank collapses to one __" do
    text = "assert m == _a(%{\n  a: 1\n})\nnext\n"
    assert Gen.learner(text) == "assert m == __\nnext\n"
    assert Gen.solutions(text) == "assert m == %{\n  a: 1\n}\nnext\n"
  end

  test "an unclosed _a( raises naming the line" do
    assert_raise ArgumentError, ~r/line 2/, fn -> Gen.learner("ok\nassert x == _a(3\n") end
  end

  describe "tagged markers" do
    test "tagged_body_block" do
      text =
        "  def f(x) do\n    # >>> answer 07: add one\n    y = x\n    y + 1\n    # <<<\n  end\n"

      assert Gen.learner(text, @no_imports) ==
               "  def f(x) do\n    # >>> 07\n    __(\"07: add one\")\n    # <<< 07\n  end\n"

      assert Gen.solutions(text) == "  def f(x) do\n    y = x\n    y + 1\n  end\n"
    end

    test "tagged_stub_block" do
      text =
        "  # >>> answer 07: handler | stub: def handle_call(_request, _from, _state)\n" <>
          "  def handle_call(:a, _from, s), do: {:reply, 1, s}\n" <>
          "  def handle_call(:b, _from, s), do: {:reply, 2, s}\n" <>
          "  # <<<\n"

      assert Gen.learner(text, @no_imports) ==
               "  # >>> 07\n" <>
                 "  def handle_call(_request, _from, _state), do: __(\"07: handler\")\n" <>
                 "  # <<< 07\n"

      assert Gen.solutions(text) ==
               "  def handle_call(:a, _from, s), do: {:reply, 1, s}\n" <>
                 "  def handle_call(:b, _from, s), do: {:reply, 2, s}\n"
    end

    test "defaulted_body_block" do
      text =
        "  def f do\n    # >>> answer 14: broadcast | default: :ok\n    send(self(), :x)\n    # <<<\n  end\n"

      assert Gen.learner(text, @no_imports) ==
               "  def f do\n    # >>> 14\n    __(\"14: broadcast\", :ok)\n    # <<< 14\n  end\n"

      assert Gen.solutions(text) == "  def f do\n    send(self(), :x)\n  end\n"
    end

    test "defaulted_stub_block" do
      text =
        "  # >>> answer 14: update | stub: def handle_info(_msg, socket) | default: {:noreply, socket}\n" <>
          "  def handle_info(:a, socket), do: {:noreply, socket}\n" <>
          "  def handle_info(:b, socket), do: {:noreply, socket}\n" <>
          "  # <<<\n"

      assert Gen.learner(text, @no_imports) ==
               "  # >>> 14\n" <>
                 "  def handle_info(_msg, socket), do: __(\"14: update\", {:noreply, socket})\n" <>
                 "  # <<< 14\n"

      assert Gen.partial(text, 13, @no_imports) == Gen.learner(text, @no_imports)
      refute Gen.partial(text, 14, @no_imports) =~ "__"
    end

    test "a default on a HEEx marker or an empty default raises naming the line" do
      heex = "<%!-- >>> answer 14: a | default: 1 --%>\nx\n<%!-- <<< --%>\n"
      assert_raise ArgumentError, ~r/line 1/, fn -> Gen.learner(heex, @no_imports) end
      empty = "a\n# >>> answer 14: a | default:\nx\n# <<<\n"

      assert_raise ArgumentError, ~r/line 2: empty default/, fn ->
        Gen.learner(empty, @no_imports)
      end
    end

    test "heex_body_block" do
      text =
        "<li>\n  <%!-- >>> answer 13: preview --%>\n  {@note.body}\n  <%!-- <<< --%>\n</li>\n"

      assert Gen.learner(text, imports: false) ==
               "<li>\n  <%!-- >>> 13 --%>\n  {__(\"13: preview\")}\n  <%!-- <<< 13 --%>\n</li>\n"

      assert Gen.solutions(text) == "<li>\n  {@note.body}\n</li>\n"
    end

    test "tilde_h_block" do
      text = """
      defmodule Easel.Page do
        def render(assigns) do
          ~H\"\"\"
          <p>
            <%!-- >>> answer 13: preview --%>
            {@note.body}
            <%!-- <<< --%>
          </p>
          \"\"\"
        end
      end
      """

      learner = Gen.learner(text, @no_imports)

      assert learner =~
               "      <%!-- >>> 13 --%>\n      {__(\"13: preview\")}\n      <%!-- <<< 13 --%>\n"

      refute learner =~ "@note.body"
      assert Gen.solutions(text) =~ "      {@note.body}\n"
    end

    test "bare markers take the chapter of the file and blank to __()" do
      text = "  # >>> answer\n  x = 1\n  # <<<\n"
      assert Gen.learner(text, chapter: "07") == "  # >>> 07\n  __()\n  # <<< 07\n"
      assert Gen.solutions(text) == "  x = 1\n"
    end

    test "bare stub blanks to a stub with __()" do
      text = "  # >>> answer stub: def f(a)\n  def f(1), do: 1\n  # <<<\n"

      assert Gen.learner(text, chapter: "07") ==
               "  # >>> 07\n  def f(a), do: __()\n  # <<< 07\n"
    end

    test "a bare marker without a chapter raises naming the line" do
      assert_raise ArgumentError, ~r/line 2.*chapter/, fn ->
        Gen.learner("a\n# >>> answer\nx\n# <<<\n")
      end
    end

    test "partial_fills_lower_chapters" do
      text = """
      defmodule Easel.Mixed do
        def seven do
          # >>> answer 07: seven
          7
          # <<<
        end

        def nine do
          # >>> answer 09: nine
          9
          # <<<
        end
      end
      """

      partial = Gen.partial(text, 7, @no_imports)
      assert partial =~ "  def seven do\n    7\n  end\n"
      assert partial =~ "    # >>> 09\n    __(\"09: nine\")\n    # <<< 09\n"
      refute partial =~ "answer"
      assert Gen.partial(text, 9, @no_imports) == Gen.solutions(text)
      assert Gen.partial(text, 0, @no_imports) == Gen.learner(text, @no_imports)
    end

    test "unmatched markers raise naming the line" do
      assert_raise ArgumentError, ~r/line 2/, fn -> Gen.learner("a\n# <<<\n") end

      assert_raise ArgumentError, ~r/line 3/, fn ->
        Gen.learner("# >>> answer 01: a\nx\n# >>> answer 01: b\n# <<<\n")
      end

      assert_raise ArgumentError, ~r/line 1/, fn -> Gen.learner("# >>> answer 01: a\nx\n") end
    end
  end

  describe "learner imports the blank macro" do
    @import_block "  # >>> course\n  import Koans, only: [__: 1, __: 2], warn: false\n  # <<< course\n"

    test "learner_imports_blank_macro" do
      text = """
      defmodule Easel.Notes do
        def one do
          # >>> answer 05: one
          1
          # <<<
        end
      end

      defmodule Easel.Plain do
        def two, do: 2
      end
      """

      learner = Gen.learner(text)
      assert learner =~ "defmodule Easel.Notes do\n" <> @import_block <> "  def one do"
      assert learner =~ "defmodule Easel.Plain do\n  def two, do: 2\n"
      refute Gen.solutions(text) =~ "course"
    end

    test "the innermost enclosing module gets the import" do
      text = """
      defmodule Outer do
        def a, do: 1

        defmodule Inner do
          def b do
            # >>> answer 05: b
            2
            # <<<
          end
        end
      end
      """

      learner = Gen.learner(text)
      assert learner =~ "defmodule Outer do\n  def a"
      assert learner =~ "  defmodule Inner do\n    # >>> course\n    import Koans"
      assert length(String.split(learner, "# >>> course")) == 2
    end

    test "heex answers inside a ~H module also trigger the import" do
      text = """
      defmodule Easel.Page do
        def render(assigns) do
          ~H\"\"\"
          <%!-- >>> answer 13: p --%>
          <p>x</p>
          <%!-- <<< --%>
          \"\"\"
        end
      end
      """

      assert Gen.learner(text) =~ "defmodule Easel.Page do\n  # >>> course\n"
    end

    test "partial builds keep the import too" do
      text = "defmodule A do\n  def f do\n    # >>> answer 05: f\n    1\n    # <<<\n  end\nend\n"
      assert Gen.partial(text, 5) =~ "# >>> course"
    end

    test "a multi-line defmodule head raises naming the line" do
      text =
        "defmodule A,\n  foo: 1 do\n  def f do\n    # >>> answer 05: f\n    1\n    # <<<\n  end\nend\n"

      assert_raise ArgumentError, ~r/line 1: cannot place the course import/, fn ->
        Gen.learner(text)
      end
    end

    test "imports can be switched off" do
      text = "defmodule A do\n  def f do\n    # >>> answer 05: f\n    1\n    # <<<\n  end\nend\n"
      refute Gen.learner(text, imports: false) =~ "course"
    end
  end

  describe "warn: false around blanks" do
    @warn_source """
    defmodule Easel.Warned do
      import Ecto.Changeset
      import Ecto.Query, only: [from: 2]
      alias Easel.Notes
      alias Easel.{Notes, Tags}
      alias Easel.Notes, as: N

      def seven(x) do
        # >>> answer 07: seven
        cast(x)
        # <<<
      end

      def two(x) do
        # >>> answer 02: two
        cast(x)
        # <<<
      end
    end
    """

    test "an unfilled blank adds warn: false to bare imports and aliases" do
      for out <- [
            Gen.learner(@warn_source, @no_imports),
            Gen.partial(@warn_source, 1, @no_imports)
          ] do
        assert out =~ "  import Ecto.Changeset, warn: false\n"
        assert out =~ "  alias Easel.Notes, warn: false\n"
        assert out =~ "  alias Easel.{Notes, Tags}, warn: false\n"
        assert out =~ "  alias Easel.Notes, as: N, warn: false\n"
        assert out =~ "  import Ecto.Query, only: [from: 2]\n"
      end
    end

    test "solutions and files with every blank filled keep the bare lines" do
      assert Gen.solutions(@warn_source) =~ "  import Ecto.Changeset\n"
      assert Gen.partial(@warn_source, 7, @no_imports) =~ "  import Ecto.Changeset\n"
      refute Gen.partial(@warn_source, 7, @no_imports) =~ "warn:"
      refute Gen.solutions(@warn_source) =~ "warn:"
    end

    test "an existing warn option and the course block are left alone" do
      text =
        "defmodule M do\n  import Foo, warn: true\n  def f do\n    # >>> answer 01: f\n    1\n    # <<<\n  end\nend\n"

      out = Gen.learner(text, chapter: "01")
      assert out =~ "  import Foo, warn: true\n"
      assert out =~ "  import Koans, only: [__: 1, __: 2], warn: false\n"
      refute out =~ "warn: true, warn: false"
      refute out =~ "warn: false, warn: false"
    end

    test "a defaulted blank counts as unfilled" do
      text =
        "defmodule M do\n  import Foo\n  def f(s) do\n    # >>> answer 05: f | default: s\n    s\n    # <<<\n  end\nend\n"

      assert Gen.learner(text, @no_imports) =~ "  import Foo, warn: false\n"
    end

    test "a file without any blank is untouched" do
      assert Gen.learner("import Foo\n", @no_imports) == "import Foo\n"
    end

    @nested_source ~S'''
    defmodule M do
      @moduledoc """
      import Doc
      """
      import Top

      defmacro __using__(_) do
        quote do
          import Quoted
        end
      end

      def f(x) do
        import Local
        # >>> answer 01: f
        x
        # <<<
      end
    end
    '''

    test "only module-level imports and aliases get warn: false" do
      out = Gen.learner(@nested_source, @no_imports)
      assert out =~ "  import Top, warn: false\n"
      assert out =~ "  import Doc\n"
      assert out =~ "      import Quoted\n"
      assert out =~ "    import Local\n"
      assert out |> String.split("warn: false") |> length() == 2
    end

    test "a course block keeps its imports bare" do
      text =
        "defmodule M do\n  # >>> course\n  import Bar\n  # <<< course\n  import Foo\n" <>
          "  def f do\n    # >>> answer 01: f\n    1\n    # <<<\n  end\nend\n"

      out = Gen.learner(text, @no_imports)
      assert out =~ "  import Foo, warn: false\n"
      assert out =~ "  import Bar\n"
    end

    test "cold output quiets module-level imports like the learner's" do
      out = Gen.cold(@warn_source, @no_imports)
      assert out =~ ~s[__("07: seven")]
      assert out =~ "  import Ecto.Changeset, warn: false\n"
      assert out =~ "  alias Easel.Notes, as: N, warn: false\n"
    end

    test "a partial with filled and open blanks quiets the imports" do
      out = Gen.partial(@warn_source, 2, @no_imports)
      assert out =~ ~s[__("07: seven")]
      refute out =~ ~s[__("02: two")]
      assert out =~ "  import Ecto.Changeset, warn: false\n"
      assert out =~ "  alias Easel.{Notes, Tags}, warn: false\n"
    end
  end

  test "a filled region drops the blank line before its close marker" do
    text =
      "defmodule M do\n  def f(x) do\n    # >>> answer 01: f\n    x\n    |> g()\n\n" <>
        "    # <<<\n  end\n\n  def h, do: 1\nend\n"

    filled = "defmodule M do\n  def f(x) do\n    x\n    |> g()\n  end\n\n  def h, do: 1\nend\n"
    assert Gen.solutions(text) == filled
    assert Gen.partial(text, 1, @no_imports) == filled
    assert Gen.learner(text, @no_imports) =~ ~s[    __("01: f")\n    # <<< 01\n  end\n\n]
  end

  describe "cold" do
    test "cold strips the numbered steps from a meditation" do
      text = ~S|  koan "Implement KV.put. 1. Take the map. 2. Put." do| <> "\n"
      assert Gen.cold(text) == ~S|  koan "Implement KV.put." do| <> "\n"
      assert Gen.learner(text) == text
    end

    test "cold strips a message-shape hint up to the end of its sentence" do
      shapes = ~S|koan "Map it. Message shapes: map([], f) is []; f.(head) first." do| <> "\n"
      assert Gen.cold(shapes) == ~S|koan "Map it." do| <> "\n"

      shape = ~S|koan "Use it. Message shape: a quote. Fill the body above." do| <> "\n"
      assert Gen.cold(shape) == ~S|koan "Use it. Fill the body above." do| <> "\n"

      both = ~S|koan "Put. Message shape: {:put, k}. 1. Match." do| <> "\n"
      assert Gen.cold(both) == ~S|koan "Put." do| <> "\n"
    end

    test "cold leaves meditations without steps alone and still blanks" do
      text = ~S|koan "Why." do| <> "\n  assert 1 == _a(1)\nend\n"
      assert Gen.cold(text) == ~S|koan "Why." do| <> "\n  assert 1 == __\nend\n"
    end

    test "cold keeps the marker comments of a code answer" do
      text = ~S|koan "Implement it. 1. Do." do| <> "\n  # >>> answer\n  x\n  # <<<\nend\n"

      assert Gen.cold(text, chapter: "03") ==
               ~S|koan "Implement it." do| <> "\n  # >>> 03\n  __()\n  # <<< 03\nend\n"
    end
  end

  describe "write_all" do
    setup do
      root = Path.join(System.tmp_dir!(), "koans_gen_#{System.unique_integer([:positive])}")
      File.mkdir_p!(Path.join(root, "source/test/koans"))
      File.mkdir_p!(Path.join(root, "source/test/support"))
      File.mkdir_p!(Path.join(root, "source/lib/easel"))
      on_exit(fn -> File.rm_rf!(root) end)
      %{root: root}
    end

    defp put(root, rel, content) do
      path = Path.join(root, rel)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end

    defp koan_file(n) do
      """
      defmodule Koans.Ch#{n}.T do
        use Koans

        koan "Why." do
          assert 1 == _a(1)
        end
      end
      """
    end

    defp lib_file do
      """
      defmodule Easel.Notes do
        def one do
          # >>> answer 07: one
          1
          # <<<
        end
      end
      """
    end

    test "no source directory is reported", %{root: root} do
      File.rm_rf!(Path.join(root, "source"))
      assert Gen.write_all(root) == {:error, :no_source}
    end

    test "writes learner and solutions, copying marker-free files verbatim", %{root: root} do
      put(root, "source/test/koans/07_a_test.exs", koan_file("07"))
      put(root, "source/lib/easel/notes.ex", lib_file())
      put(root, "source/lib/easel/plain.ex", "defmodule Easel.Plain do\nend\n")
      put(root, "source/test/support/helper.ex", "defmodule Easel.Helper do\nend\n")

      assert {:ok, 8} = Gen.write_all(root)
      assert File.read!(Path.join(root, "test/koans/07_a_test.exs")) =~ "assert 1 == __"
      assert File.read!(Path.join(root, "solutions/test/koans/07_a_test.exs")) =~ "assert 1 == 1"

      learner = File.read!(Path.join(root, "lib/easel/notes.ex"))
      assert learner =~ "__(\"07: one\")"
      assert learner =~ "# >>> course"
      solution = File.read!(Path.join(root, "solutions/lib/easel/notes.ex"))
      assert solution =~ "    1\n"
      refute solution =~ ">>>"

      for side <- ["", "solutions/"] do
        assert File.read!(Path.join(root, side <> "lib/easel/plain.ex")) ==
                 "defmodule Easel.Plain do\nend\n"

        assert File.exists?(Path.join(root, side <> "test/support/helper.ex"))
      end
    end

    test "only limits koan files and writes lib whole", %{root: root} do
      put(root, "source/test/koans/07_a_test.exs", koan_file("07"))
      put(root, "source/test/koans/09_b_test.exs", koan_file("09"))
      put(root, "source/lib/easel/notes.ex", lib_file())

      assert {:ok, 4} = Gen.write_all(root, ["09"])
      refute File.exists?(Path.join(root, "test/koans/07_a_test.exs"))
      assert File.exists?(Path.join(root, "test/koans/09_b_test.exs"))
      assert File.exists?(Path.join(root, "lib/easel/notes.ex"))
    end

    test "source errors abort before writing", %{root: root} do
      put(root, "source/test/koans/01_a_test.exs", "x = _a(1)\n")
      assert {:error, [msg]} = Gen.write_all(root)
      assert msg =~ "source/test/koans/01_a_test.exs:1:"
      refute File.exists?(Path.join(root, "test"))
    end

    test "an answer tag naming a missing chapter aborts", %{root: root} do
      put(root, "source/test/koans/09_b_test.exs", koan_file("09"))
      put(root, "source/lib/easel/notes.ex", lib_file())
      assert {:error, [msg]} = Gen.write_all(root)
      assert msg =~ "chapter 07 with no koan file"
    end
  end
end
