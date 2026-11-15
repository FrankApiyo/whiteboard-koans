defmodule Verify.SourceCheckTest do
  use ExUnit.Case, async: true

  alias Koans.SourceCheck

  @path "source/test/koans/01_x_test.exs"
  @lib "source/lib/easel/thing.ex"

  defp koan_file(body) do
    "defmodule T do\n  use Koans\n\n  koan \"Why.\" do\n" <> body <> "  end\nend\n"
  end

  defp errors(text) do
    assert {:error, list} = SourceCheck.check(text, @path)
    list
  end

  test "a clean file is ok" do
    text = koan_file("    x = 1\n    assert x == _a(1)\n    assert_receive {:ok, 1}\n")
    assert SourceCheck.check(text, @path) == :ok
  end

  test "blank outside a koan body" do
    text = "defmodule T do\n  @a _a(1)\nend\n"
    assert "#{@path}:2: value blank outside a koan body" in errors(text)
  end

  test "blank left of =" do
    assert "#{@path}:5: value blank in a pattern" in errors(koan_file("    _a(1) = 1\n"))
  end

  test "blank in assert x = y pattern" do
    assert "#{@path}:5: value blank in a pattern" in errors(
             koan_file("    assert {_a(1), 2} = {1, 2}\n")
           )
  end

  test "blank as match? first argument" do
    assert "#{@path}:5: value blank in a pattern" in errors(
             koan_file("    assert match?(_a(1), 1)\n")
           )
  end

  test "blank as match? second argument is allowed" do
    assert SourceCheck.check(koan_file("    assert match?(1, _a(1))\n"), @path) == :ok
  end

  for name <- ~w(assert_receive assert_received refute_receive refute_received) do
    test "blank in #{name}" do
      text = koan_file("    #{unquote(name)}({:ok, _a(1)})\n")
      assert "#{@path}:5: value blank in a pattern" in errors(text)
    end
  end

  test "blank left of <-" do
    text = koan_file("    for _a(1) <- [1], do: 1\n")
    assert "#{@path}:5: value blank in a pattern" in errors(text)
  end

  test "blank in a -> clause head" do
    text = koan_file("    case 1 do\n      _a(1) -> :ok\n    end\n")
    assert "#{@path}:6: value blank in a pattern" in errors(text)
  end

  test "blank in a def head" do
    text = "defmodule T do\n  def f(_a(1)), do: 1\nend\n"
    assert "#{@path}:2: value blank in a pattern" in errors(text)
  end

  test "blank under != and !==" do
    assert "#{@path}:5: value blank compared with != or under refute" in errors(
             koan_file("    assert 1 != _a(2)\n")
           )

    assert "#{@path}:5: value blank compared with != or under refute" in errors(
             koan_file("    assert 1 !== _a(2)\n")
           )
  end

  test "blank under refute" do
    assert "#{@path}:5: value blank compared with != or under refute" in errors(
             koan_file("    refute 1 == _a(2)\n")
           )
  end

  defp stub_file(clauses_in_block, extra_outside \\ "") do
    """
    defmodule T do
      use Koans

      # >>> answer stub: def handle_call(_request, _from, _state)
    #{clauses_in_block}  # <<<
    #{extra_outside}
      koan "Implement handle_call." do
        assert 1 == _a(1)
      end
    end
    """
  end

  test "a complete stub block is ok" do
    block = "  def handle_call(:a, _f, s), do: s\n  def handle_call(:b, _f, s), do: s\n"
    assert SourceCheck.check(stub_file(block), @path) == :ok
  end

  test "a stub block missing a clause of the module" do
    block = "  def handle_call(:a, _f, s), do: s\n"
    outside = "  def handle_call(:b, _f, s), do: s\n"

    assert "#{@path}:4: stub block does not cover every clause of handle_call/3" in errors(
             stub_file(block, outside)
           )
  end

  test "a stub block with more than three clauses" do
    block = for(n <- 1..4, into: "", do: "  def handle_call(#{n}, _f, s), do: s\n")
    assert "#{@path}:4: stub block holds more than three clauses" in errors(stub_file(block))
  end

  test "a code block without an Implement meditation" do
    text = """
    defmodule T do
      use Koans

      koan "Why." do
        # >>> answer
        x = 1
        # <<<
        assert x == 1
      end
    end
    """

    assert "#{@path}:5: file has a code block but no meditation containing Implement" in errors(
             text
           )
  end

  test "a code block with an Implement meditation is ok" do
    text = """
    defmodule T do
      use Koans

      koan "Implement it." do
        # >>> answer
        x = 1
        # <<<
        assert x == 1
      end
    end
    """

    assert SourceCheck.check(text, @path) == :ok
  end

  describe "tagged markers" do
    defp lib_errors(text, opts \\ [chapters: ["04", "13"]]) do
      assert {:error, list} = SourceCheck.check(text, @lib, opts)
      list
    end

    defp mark(indent \\ "    "),
      do: "#{indent}# >>> answer 04: x\n#{indent}y\n#{indent}# <<<"

    defp marker_line(text),
      do: Enum.find_index(String.split(text, "\n"), &(&1 =~ ">>> answer")) + 1

    test "unparseable source is reported, not raised" do
      assert {:error, [message]} = SourceCheck.check("defmodule T do\n  def f(\n", @lib)
      assert message =~ ~r/\A#{@lib}:\d+: syntax error/
    end

    defp default_text(header),
      do:
        "defmodule Easel.T do\n  def f(socket) do\n    # >>> answer #{header}\n    y\n    # <<<\n  end\nend\n"

    test "a defaulted marker is ok" do
      text = default_text("04: sub | default: {:noreply, socket}")
      assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
    end

    test "an empty default is an error" do
      assert "#{@lib}:3: empty default expression" in lib_errors(
               default_text("04: sub | default:")
             )
    end

    test "a default that is not an expression is an error" do
      assert "#{@lib}:3: default is not a valid expression" in lib_errors(
               default_text("04: sub | default: {:a,")
             )
    end

    test "a default written before the stub is malformed" do
      header = "04: sub | default: {:ok, 1} | stub: def f(a)"
      assert "#{@lib}:3: malformed answer marker" in lib_errors(default_text(header))
    end

    test "a default on a HEEx marker is an error" do
      text = "<%!-- >>> answer 13: a | default: 1 --%>\n{@x}\n<%!-- <<< --%>\n"
      assert {:error, list} = SourceCheck.check(text, "source/lib/x.html.heex", chapters: ["13"])
      assert "source/lib/x.html.heex:1: default is not allowed on a HEEx marker" in list
    end

    test "a tagged lib answer is ok" do
      text = "defmodule Easel.T do\n  def f do\n#{mark()}\n  end\nend\n"
      assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
    end

    test "a bare marker outside test/koans needs a tag" do
      text = "defmodule Easel.T do\n  def f do\n    # >>> answer\n    y\n    # <<<\n  end\nend\n"
      assert "#{@lib}:3: answer marker needs a NN: tag" in lib_errors(text)
    end

    test "a malformed marker" do
      text =
        "defmodule Easel.T do\n  def f do\n    # >>> answer seven: x\n    y\n    # <<<\n  end\nend\n"

      assert "#{@lib}:3: malformed answer marker" in lib_errors(text)
    end

    test "answer tag naming a chapter with no koan file" do
      text = "defmodule Easel.T do\n  def f do\n#{mark()}\n  end\nend\n"

      assert "#{@lib}:3: answer tag names chapter 04 with no koan file" in lib_errors(text,
               chapters: ["01"]
             )
    end

    test "a heex marker not on its own line" do
      text = "<p>\n  <p>x</p> <%!-- >>> answer 13: a --%>\n</p>\n"

      assert {:error, list} =
               SourceCheck.check(text, "source/lib/easel_web/x.html.heex", chapters: ["13"])

      assert "source/lib/easel_web/x.html.heex:2: heex marker not on its own line" in list
    end

    test "a heex marker on its own line is ok" do
      text = "<p>\n  <%!-- >>> answer 13: a --%>\n  {@x}\n  <%!-- <<< --%>\n</p>\n"
      assert SourceCheck.check(text, "source/lib/x.html.heex", chapters: ["13"]) == :ok
    end

    test "unpaired heex markers are reported" do
      text = "<%!-- >>> answer 13: a --%>\n{@x}\n"
      assert {:error, list} = SourceCheck.check(text, "source/lib/x.html.heex", chapters: ["13"])
      assert "source/lib/x.html.heex:1: unmatched answer marker" in list
    end

    @never_blank [
      {"schema", "  schema \"n\" do\n#MARK\n  end", "schema"},
      {"embedded_schema", "  embedded_schema do\n#MARK\n  end", "embedded_schema"},
      {"object", "  object :a do\n#MARK\n  end", "object"},
      {"input_object", "  input_object :a do\n#MARK\n  end", "input_object"},
      {"field", "  object :a do\n    field :b, :string do\n#MARK\n    end\n  end", "field"},
      {"arg",
       "  object :a do\n    field :b, :string do\n      arg :c, :string do\n#MARK\n      end\n    end\n  end",
       "arg"},
      {"query_field", "  query do\n    field :b, :string do\n#MARK\n    end\n  end", "field"},
      {"ecto_field", "  schema \"n\" do\n    field :b, :string do\n#MARK\n    end\n  end",
       "field"},
      {"pipeline", "  pipeline :browser do\n#MARK\n  end", "pipeline"},
      {"scope", "  scope \"/\" do\n#MARK\n  end", "scope"},
      {"live_session", "  live_session :a do\n#MARK\n  end", "live_session"},
      {"attr", "  attr :a, :string do\n#MARK\n  end", "attr"},
      {"slot", "  slot :a do\n#MARK\n  end", "slot"},
      {"plug_init", "  def init(opts) do\n#MARK\n  end\n  def call(conn, _), do: conn",
       "def init/1 of a plug"},
      {"application_start", "  use Application\n  def start(_t, _a) do\n#MARK\n  end",
       "Application.start/2"},
      {"middleware", "  use Absinthe.Schema\n  def middleware(m, _f, _o) do\n#MARK\n  end",
       "Absinthe middleware/3"},
      {"context", "  use Absinthe.Schema\n  def context(ctx) do\n#MARK\n  end",
       "Absinthe context/1"},
      {"plugins", "  use Absinthe.Schema\n  def plugins do\n#MARK\n  end", "Absinthe plugins/0"},
      {"static_paths", "  def static_paths do\n#MARK\n  end", "static_paths/0"}
    ]

    for {name, body, label} <- @never_blank do
      test "never a blank: #{name}" do
        text =
          "defmodule Easel.T do\n" <>
            String.replace(unquote(body), "#MARK", mark("    ")) <> "\nend\n"

        line = marker_line(text)

        assert "#{@lib}:#{line}: marker inside a never-a-blank construct: #{unquote(label)}" in lib_errors(
                 text
               )
      end
    end

    defp easel_module(body), do: "defmodule Easel.T do\n" <> body <> "\nend\n"

    test "a stub whose clauses are named like a never-blank macro does not flag itself" do
      for name <- ~w(field scope schema arg object) do
        text =
          easel_module(
            "  # >>> answer 04: x | stub: def #{name}(a)\n  def #{name}(1), do: 1\n  def #{name}(2), do: 2\n  # <<<"
          )

        assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
      end
    end

    defp mark_code(code), do: "    # >>> answer 04: x\n    #{code}\n    # <<<"

    test "field in a query is allowed" do
      text =
        easel_module(
          "  def sorted(q, sort) do\n#{mark_code("from(n in q, order_by: field(n, ^sort))")}\n  end"
        )

      assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
    end

    test "field in where, select and dynamic arguments is allowed inside an answer" do
      code =
        "from(n in Note, where: field(n, ^s) == 1, select: field(n, :id))\n    dynamic([n], field(n, ^s))"

      text = easel_module("  def q(s) do\n#{mark_code(code)}\n  end")
      assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
    end

    test "object used as a variable or function call outside a schema body is allowed" do
      text =
        easel_module(
          "  def f(object) do\n#{mark_code("object = object(object)\n    object")}\n  end"
        )

      assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
    end

    test "a plug whose call matches %Plug.Conn{} = conn still owns init" do
      for first <- ["%Plug.Conn{} = conn", "conn = %Plug.Conn{}"] do
        text =
          easel_module(
            "  def init(opts) do\n#{mark()}\n  end\n  def call(#{first}, _opts), do: conn"
          )

        line = marker_line(text)

        assert "#{@lib}:#{line}: marker inside a never-a-blank construct: def init/1 of a plug" in lib_errors(
                 text
               )
      end
    end

    test "a GenServer with a client call/2 may blank init" do
      text =
        easel_module(
          "  use GenServer\n  def call(server, msg), do: GenServer.call(server, msg)\n  def init(arg) do\n#{mark()}\n  end"
        )

      assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
    end

    test "use Plug.Builder and @behaviour Plug make init a plug init" do
      for head <- ["use Plug.Builder", "@behaviour Plug"] do
        text = easel_module("  #{head}\n  def init(opts) do\n#{mark()}\n  end")
        line = marker_line(text)

        assert "#{@lib}:#{line}: marker inside a never-a-blank construct: def init/1 of a plug" in lib_errors(
                 text
               )
      end
    end

    test "a plug without call/2 may blank init" do
      text = "defmodule Easel.T do\n  def init(opts) do\n#{mark()}\n  end\nend\n"
      assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
    end

    test "init outside the marker is fine in a plug" do
      text =
        "defmodule Easel.T do\n  def init(opts), do: opts\n  def call(conn, _) do\n#{mark()}\n  end\nend\n"

      assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
    end

    test "value blank in a lib file is outside a koan body" do
      text = "defmodule Easel.T do\n  @a _a(1)\nend\n"
      assert "#{@lib}:2: value blank outside a koan body" in lib_errors(text)
    end

    test "a lib file without koans needs no Implement meditation" do
      text = "defmodule Easel.T do\n  def f do\n#{mark()}\n  end\nend\n"
      assert SourceCheck.check(text, @lib, chapters: ["04"]) == :ok
    end
  end

  describe "generated blank width" do
    defp wide_stub_file(tag) do
      "defmodule Easel.T do\n  # >>> answer 04: #{tag} | stub: defp broadcast(result, _scope) | default: result\n" <>
        "  defp broadcast(result, _scope), do: result\n  # <<<\nend\n"
    end

    test "a blank whose generated line fits in 98 columns is fine" do
      assert SourceCheck.check(wide_stub_file("broadcast the note"), @lib, chapters: ["04"]) ==
               :ok
    end

    test "a blank whose generated line is over 98 columns names its width" do
      tag = String.duplicate("x", 43)
      width = String.length(~s[  defp broadcast(result, _scope), do: __("04: #{tag}", result)])
      assert width == 99

      assert {:error, [message]} = SourceCheck.check(wide_stub_file(tag), @lib, chapters: ["04"])
      assert message == "#{@lib}:2: generated blank is 99 columns, over 98: shorten the tag"
    end
  end
end
