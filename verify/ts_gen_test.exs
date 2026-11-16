defmodule Verify.TsGenTest do
  use ExUnit.Case, async: false

  alias Koans.{Chapters, Gen}

  @ts [ext: ".ts"]
  @svelte [ext: ".svelte"]

  defp fill(text, blank_line, code), do: String.replace(text, blank_line <> "\n", code <> "\n")

  test "ts_body_block" do
    text = """
    export function contains(r: Rect, px: number, py: number): boolean {
      // >>> answer 02: hit test
      const inX = px >= r.x && px <= r.x + r.w
      return inX && py >= r.y && py <= r.y + r.h
      // <<<
    }
    """

    assert Gen.learner(text, @ts) == """
           export function contains(r: Rect, px: number, py: number): boolean {
             // >>> 02
             __blank("02: hit test");
             // <<< 02
           }
           """

    assert Gen.solutions(text, @ts) == """
           export function contains(r: Rect, px: number, py: number): boolean {
             const inX = px >= r.x && px <= r.x + r.w
             return inX && py >= r.y && py <= r.y + r.h
           }
           """
  end

  test "ts_defaulted_block" do
    text = """
    export function listen(target: EventTarget, f: () => void): () => void {
      // >>> answer 10: listen | default: () => {}
      target.addEventListener("x", f)
      return () => target.removeEventListener("x", f)
      // <<<
    }
    """

    learner = Gen.learner(text, @ts)
    assert learner =~ "  // >>> 10\n  return __blank(\"10: listen\", () => {});\n  // <<< 10\n"
    assert Gen.partial(text, 9, @ts) == learner
    assert Gen.partial(text, 10, @ts) == Gen.solutions(text, @ts)
    refute Gen.solutions(text, @ts) =~ "__blank"
  end

  @svelte_source """
  <script lang="ts">
    let { people }: { people: string[] } = $props()

    function initials(name: string): string {
      // >>> answer 03: initials
      return name.slice(0, 1)
      // <<<
    }
  </script>

  <ul>
    <!-- >>> answer 03: people list -->
    {#each people as person}
      <li>{initials(person)}</li>
    {/each}
    <!-- <<< -->
  </ul>
  """

  test "svelte_script_and_markup_blocks" do
    learner = Gen.learner(@svelte_source, @svelte)

    assert learner =~
             "  function initials(name: string): string {\n" <>
               "    // >>> 03\n    __blank(\"03: initials\");\n    // <<< 03\n  }\n"

    assert learner =~
             "<ul>\n  <!-- >>> 03 -->\n  {__blank(\"03: people list\", \"\")}\n  <!-- <<< 03 -->\n</ul>\n"

    refute learner =~ "{#each"

    solutions = Gen.solutions(@svelte_source, @svelte)
    assert solutions =~ "    return name.slice(0, 1)\n  }\n"
    assert solutions =~ "<ul>\n  {#each people as person}\n"
    refute solutions =~ ">>>"
    refute solutions =~ "<<<"
  end

  test "a default on a markup marker raises naming the line" do
    text = "<p>\n  <!-- >>> answer 03: a | default: 1 -->\n  x\n  <!-- <<< -->\n</p>\n"

    assert_raise ArgumentError, ~r/line 2: default is not allowed on a markup marker/, fn ->
      Gen.learner(text, @svelte)
    end
  end

  test "untagged and stub markers are malformed in typescript" do
    for marker <- ["// >>> answer", "// >>> answer 03: f | stub: function f()"] do
      assert_raise ArgumentError, ~r/line 2: malformed answer marker/, fn ->
        Gen.learner("a\n#{marker}\nx\n// <<<\n", @ts)
      end
    end
  end

  test "ts_value_blanks" do
    text = "  expect(x).toBe(_a(`a${b}`))\n"
    assert Gen.learner(text, @ts) == "  expect(x).toBe(__)\n"
    assert Gen.solutions(text, @ts) == "  expect(x).toBe(`a${b}`)\n"

    assert_raise ArgumentError, ~r/line 2: _a\( without a closing paren/, fn ->
      Gen.learner("ok\nexpect(x).toBe(_a(3\n", @ts)
    end
  end

  test "the value scanner skips strings, templates and comments" do
    inner = ~S|f(")", '(', `)${g(")", `(`)}`, a / b) // )| <> "\n  /* ) */ + 1"
    text = "expect(x).toBe(_a(#{inner}))\nnext\n"
    assert Gen.learner(text, @ts) == "expect(x).toBe(__)\nnext\n"
    assert Gen.solutions(text, @ts) == "expect(x).toBe(#{inner})\nnext\n"
  end

  test "a nested _a( or a regex literal inside one raises naming the line" do
    assert_raise ArgumentError, ~r/line 2: nested _a\(/, fn ->
      Gen.learner("ok\nexpect(_a(_a(1))).toBe(1)\n", @ts)
    end

    assert_raise ArgumentError, ~r/line 3: regex literal inside _a\(/, fn ->
      Gen.learner("ok\nexpect(x).toBe(_a(\n  /a)/.test(s)))\n", @ts)
    end
  end

  test "a regex after a keyword, a closing brace or a control paren raises" do
    for code <- ["f(() => { return /a)/.test(s) })", "() => { if (x) /a)/.test(s) }", "{} /a)/"] do
      assert_raise ArgumentError, ~r/line 2: regex literal inside _a\(/, fn ->
        Gen.learner("ok\nexpect(_a(#{code})).toBe(1)\n", @ts)
      end
    end

    assert Gen.solutions("expect(_a(f(a) / 2)).toBe(1)\n", @ts) == "expect(f(a) / 2).toBe(1)\n"
  end

  test "an _a( inside a string or comment within _a( is not nested" do
    inner = ~S|"_a(" + f(/* _a( */ 1) + `_a(`|
    text = "expect(_a(#{inner})).toBe(1)\n"
    assert Gen.learner(text, @ts) == "expect(__).toBe(1)\n"
    assert Gen.solutions(text, @ts) == "expect(#{inner}).toBe(1)\n"

    assert_raise ArgumentError, ~r/line 3: nested _a\(/, fn ->
      Gen.learner("ok\nexpect(_a(1 +\n  _a(2))).toBe(3)\n", @ts)
    end
  end

  test "nested braces inside a template interpolation" do
    inner = ~S|`${ {a: "}"}.a }-${ `${1}` }`|
    text = "expect(_a(#{inner})).toBe(1)\n"
    assert Gen.learner(text, @ts) == "expect(__).toBe(1)\n"
    assert Gen.solutions(text, @ts) == "expect(#{inner}).toBe(1)\n"
  end

  test "js files dispatch to the typescript generator" do
    text = "export function f() {\n  // >>> answer 02: f\n  return 1\n  // <<<\n}\n"
    js = [ext: ".js"]

    assert Gen.learner(text, js) ==
             "export function f() {\n  // >>> 02\n  __blank(\"02: f\");\n  // <<< 02\n}\n"

    assert Gen.solutions(text, js) == "export function f() {\n  return 1\n}\n"
  end

  test "a name ending in _a( is not a blank" do
    assert Gen.learner("data_a(1); $_a(2); o._a(3)\n", @ts) == "data_a(1); $_a(2); o._a(3)\n"
  end

  test "partial_fills_lower_chapters_in_ts" do
    text = """
    export function seven(): number {
      // >>> answer 07: seven
      return 7
      // <<<
    }

    export function nine(): number {
      // >>> answer 09: nine
      return 9
      // <<<
    }
    """

    partial = Gen.partial(text, 7, @ts)
    assert partial =~ "export function seven(): number {\n  return 7\n}\n"
    assert partial =~ "  // >>> 09\n  __blank(\"09: nine\");\n  // <<< 09\n"
    refute partial =~ "answer"
    assert Gen.partial(text, 9, @ts) == Gen.solutions(text, @ts)
    assert Gen.partial(text, 0, @ts) == Gen.learner(text, @ts)
  end

  defp ex_source do
    """
    defmodule Verify.TsReset do
      def nine(x) do
        # >>> answer 09: nine
        x + 9
        # <<<
      end

      def ten(x) do
        # >>> answer 10: ten
        x * 10
        # <<<
      end
    end
    """
  end

  defp ts_source do
    """
    export function nine(x: number): number {
      // >>> answer 09: nine ts
      return x + 9
      // <<<
    }

    export function ten(x: number): number {
      // >>> answer 10: ten ts
      return x * 10
      // <<<
    }
    """
  end

  defp svelte_source do
    """
    <script lang="ts">
      let { n }: { n: number } = $props()

      function label(): string {
        // >>> answer 09: label
        return `#${n}`
        // <<<
      }

      function title(): string {
        // >>> answer 10: title
        return "T"
        // <<<
      }
    </script>

    <!-- >>> answer 09: badge -->
    <span>{label()}</span>
    <!-- <<< -->
    <!-- >>> answer 10: heading -->
    <h2>{title()}</h2>
    <!-- <<< -->
    """
  end

  defp fill_ex(text, "09"), do: fill(text, ~S|    __("09: nine")|, "    y = x\n    y + 90")
  defp fill_ex(text, "10"), do: fill(text, ~S|    __("10: ten")|, "    z = x\n    z * 100")

  defp fill_ts(text, "09"),
    do: fill(text, ~S|  __blank("09: nine ts");|, "  const y = x\n  return y + 90")

  defp fill_ts(text, "10"),
    do: fill(text, ~S|  __blank("10: ten ts");|, "  const z = x\n  return z * 100")

  defp fill_svelte(text, "09") do
    text
    |> fill(~S|    __blank("09: label");|, "    return `n=${n}`")
    |> fill(~S|{__blank("09: badge", "")}|, "<b>{label()}</b>")
  end

  defp fill_svelte(text, "10") do
    text
    |> fill(~S|    __blank("10: title");|, "    const t = \"Title\"\n    return t")
    |> fill(~S|{__blank("10: heading", "")}|, "<h3>{title()}</h3>")
  end

  test "reset_reblanks_both_languages" do
    cases = [
      {ex_source(), [], &fill_ex/2},
      {ts_source(), @ts, &fill_ts/2},
      {svelte_source(), @svelte, &fill_svelte/2}
    ]

    for {source, opts, filler} <- cases do
      learner = Gen.learner(source, Keyword.put(opts, :imports, false))
      filled = learner |> filler.("09") |> filler.("10")
      assert filled != learner
      refute filled =~ ~r/__(blank)?\("(09|10): /

      reset = Gen.reblank(filled, source, "09", opts)

      assert reset == filler.(learner, "10")
      assert reset =~ ~r/__(blank)?\("09: /
      refute reset =~ ~r/__(blank)?\("10: /
    end

    svelte = Gen.learner(svelte_source(), @svelte)

    reset =
      svelte
      |> fill_svelte("09")
      |> fill_svelte("10")
      |> Gen.reblank(svelte_source(), "09", @svelte)

    assert reset =~ "<!-- >>> 09 -->\n{__blank(\"09: badge\", \"\")}\n<!-- <<< 09 -->\n"
    assert reset =~ "<!-- >>> 10 -->\n<h3>{title()}</h3>\n<!-- <<< 10 -->\n"
  end

  test "a_deleted_ts_close_marker_raises_naming_the_line" do
    learner = Gen.learner(ts_source(), @ts)
    damaged = String.replace(learner, "  // <<< 09\n", "")
    assert damaged != learner

    [before_open | _] = String.split(damaged, "// >>> 09")
    line = length(String.split(before_open, "\n"))
    assert line == 2

    assert_raise ArgumentError, ~r/line #{line}: \/\/ >>> 09 never closed/, fn ->
      Gen.reblank(damaged, ts_source(), "09", @ts)
    end

    markup = Gen.learner(svelte_source(), @svelte)
    broken = String.replace(markup, "<!-- <<< 09 -->\n", "")
    assert broken != markup

    [before_markup | _] = String.split(broken, "<!-- >>> 09 -->")
    markup_line = length(String.split(before_markup, "\n"))
    assert markup_line == 17

    assert_raise ArgumentError, ~r/line #{markup_line}: <!-- >>> 09 --> never closed/, fn ->
      Gen.reblank(broken, svelte_source(), "09", @svelte)
    end
  end

  test "cold_strips_steps_from_ts_meditations" do
    text = """
    test("Implement contains. 1. Check x. 2. Check y.", () => {
      expect(contains(r, 1, 1)).toBe(_a(true))
    })

    test("Why it holds.", () => {
      expect(1).toBe(_a(1))
    })
    """

    assert Gen.cold(text, @ts) == """
           test("Implement contains.", () => {
             expect(contains(r, 1, 1)).toBe(__)
           })

           test("Why it holds.", () => {
             expect(1).toBe(__)
           })
           """

    assert Gen.learner(text, @ts) =~ ~S|test("Implement contains. 1. Check x. 2. Check y."|
  end

  describe "project trees" do
    setup do
      root = Path.join(System.tmp_dir!(), "koans_ts_gen_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(root) end)
      %{root: root}
    end

    defp put(root, rel, content) do
      path = Path.join(root, rel)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end

    defp ex_koan(n) do
      """
      defmodule Koans.Ch#{n}.T do
        use Koans

        koan "Implement it. 1. Do it. Ok." do
          assert 1 == _a(1)
        end
      end
      """
    end

    defp ts_koan(n) do
      markup = %{"09" => "09: badge", "10" => "10: heading"}

      """
      import { expect } from "vitest"
      import { test } from "@koans/runtime"

      test("Implement it. 1. Do it.", () => {
        expect(1).toBe(_a(#{n}))
      }, { exercises: ["#{n}: drill #{n}", "#{markup[n]}"] })
      """
    end

    defp drill(n) do
      ~s|<script lang="ts">\n</script>\n\n| <>
        "<!-- >>> answer #{n}: drill #{n} -->\n<p>drill</p>\n<!-- <<< -->\n"
    end

    defp lib(n) do
      "defmodule Easel.M#{n} do\n  def f(x) do\n    # >>> answer #{n}: f\n    x\n    # <<<\n  end\nend\n"
    end

    defp seed(root) do
      put(root, "source/lib/easel/m.ex", ex_source())
      put(root, "source/assets/js/m.ts", ts_source())
      put(root, "source/assets/svelte/M.svelte", svelte_source())
      put(root, "source/assets/test/support/fake.ts", "export const fake = 1\n")

      for n <- ["09", "10"] do
        put(root, "source/test/koans/#{n}_t_test.exs", ex_koan(n))
        put(root, "source/assets/koans/#{n}_t.test.ts", ts_koan(n))
        put(root, "source/assets/koans/drills/#{n}_badge.svelte", drill(n))
      end
    end

    defp tsconfig_ok?(path) do
      config = path |> File.read!() |> JSON.decode!()

      config["extends"] == "../../assets/tsconfig.json" and
        "../../assets/koans_support/**/*" in config["include"] and
        "koans/**/*" in config["include"] and
        config["compilerOptions"]["paths"] == %{
          "@koans/*" => ["../../assets/koans_support/*"]
        }
    end

    test "write_all_writes_ts_trees", %{root: root} do
      seed(root)

      assert {:ok, 20, _} = Gen.write_all(root)

      js = File.read!(Path.join(root, "assets/js/m.ts"))
      assert js =~ "  // >>> 09\n  __blank(\"09: nine ts\");\n  // <<< 09\n"
      assert File.read!(Path.join(root, "solutions/assets/js/m.ts")) =~ "  return x + 9\n"

      svelte = File.read!(Path.join(root, "assets/svelte/M.svelte"))
      assert svelte =~ ~S|{__blank("10: heading", "")}|
      refute File.read!(Path.join(root, "solutions/assets/svelte/M.svelte")) =~ "__blank"

      koan = File.read!(Path.join(root, "assets/koans/09_t.test.ts"))
      assert koan =~ "expect(1).toBe(__)"
      assert File.read!(Path.join(root, "solutions/assets/koans/09_t.test.ts")) =~ "toBe(09)"

      assert File.read!(Path.join(root, "assets/koans/drills/10_badge.svelte")) =~
               "<!-- >>> 10 -->\n{__blank(\"10: drill 10\", \"\")}\n<!-- <<< 10 -->\n"

      assert File.read!(Path.join(root, "assets/test/support/fake.ts")) ==
               "export const fake = 1\n"

      assert File.read!(Path.join(root, "lib/easel/m.ex")) =~ ~S|__("09: nine")|

      assert tsconfig_ok?(Path.join(root, "solutions/assets/tsconfig.json"))
      refute File.exists?(Path.join(root, "assets/tsconfig.json"))
      assert {:error, :enoent} = File.lstat(Path.join(root, "solutions/assets/node_modules"))

      assert {:ok, _, _} = Gen.write_all(root, ["10"])
      put(root, "assets/koans/09_t.test.ts", "// mine\n")
      assert {:ok, 14, _} = Gen.write_all(root, ["10"])
      assert File.read!(Path.join(root, "assets/koans/09_t.test.ts")) == "// mine\n"
    end

    test "write_all_reports_typescript_source_errors", %{root: root} do
      seed(root)
      put(root, "source/assets/js/bad.ts", "export const x = _a(1)\n")
      put(root, "source/assets/svelte/Plain.svelte", "<p>plain</p>\n")

      assert Gen.write_all(root) ==
               {:error,
                [
                  "source/assets/js/bad.ts:1: value blank outside a test body",
                  ~s|source/assets/svelte/Plain.svelte:1: component has no <script lang="ts">|
                ]}

      refute File.exists?(Path.join(root, "assets/js/m.ts"))
    end

    test "a ts answer tag counts its chapter from assets/koans", %{root: root} do
      put(root, "source/lib/easel/m.ex", lib("04"))
      put(root, "source/assets/koans/04_t.test.ts", ts_koan("04"))
      assert {:ok, 4, _} = Gen.write_all(root)
    end

    test "chapters_build_writes_verify_assets", %{root: root} do
      seed(root)
      Chapters.build(9, root)

      verify = Path.join(root, "_verify")
      js = Path.join(verify, "assets/js/m.ts")
      assert File.read!(js) =~ "  return x + 9\n"
      assert File.read!(js) =~ ~S|__blank("10: ten ts");|

      svelte = File.read!(Path.join(verify, "assets/svelte/M.svelte"))
      assert svelte =~ "<span>{label()}</span>"
      assert svelte =~ ~S|{__blank("10: heading", "")}|

      assert File.read!(Path.join(verify, "assets/koans/09_t.test.ts")) =~ "toBe(09)"
      assert File.read!(Path.join(verify, "assets/koans/10_t.test.ts")) =~ "toBe(__)"

      assert File.read!(Path.join(verify, "assets/koans/drills/09_badge.svelte")) =~
               "<p>drill</p>"

      assert File.read!(Path.join(verify, "assets/koans/drills/10_badge.svelte")) =~ "__blank"
      assert File.read!(Path.join(verify, "lib/easel/m.ex")) =~ "    x + 9\n"

      tsconfig = Path.join(verify, "assets/tsconfig.json")
      assert tsconfig_ok?(tsconfig)
      assert {:error, :enoent} = File.lstat(Path.join(verify, "assets/node_modules"))

      old = {{2000, 1, 1}, {0, 0, 0}}
      for path <- [tsconfig, js], do: File.touch!(path, old)
      Chapters.build(9, root)
      assert File.stat!(tsconfig, time: :universal).mtime == old
      assert File.stat!(js, time: :universal).mtime == old

      Chapters.build(10, root)
      assert File.stat!(tsconfig, time: :universal).mtime == old
      refute File.read!(js) =~ "__blank"
    end

    defp run_task(task, args), do: ExUnit.CaptureIO.capture_io(fn -> task.run(args) end)

    test "reset NN restores both koan files and drills and reblanks both languages", %{
      root: root
    } do
      seed(root)
      run_task(Mix.Tasks.Koans.Gen, ["--root", root])

      edits = [
        {"lib/easel/m.ex", &fill_ex/2},
        {"assets/js/m.ts", &fill_ts/2},
        {"assets/svelte/M.svelte", &fill_svelte/2}
      ]

      pristine = Map.new(edits, fn {rel, _} -> {rel, File.read!(Path.join(root, rel))} end)

      for {rel, filler} <- edits do
        path = Path.join(root, rel)
        File.write!(path, path |> File.read!() |> filler.("09") |> filler.("10"))
      end

      scribbled =
        for n <- ["09", "10"],
            rel <-
              ["test/koans/#{n}_t_test.exs", "assets/koans/#{n}_t.test.ts"] ++
                ["assets/koans/drills/#{n}_badge.svelte"],
            do: rel

      restored = Map.new(scribbled, &{&1, File.read!(Path.join(root, &1))})
      for rel <- scribbled, do: File.write!(Path.join(root, rel), "// scribble\n")

      output = run_task(Mix.Tasks.Koans.Reset, ["09", "--root", root])

      for {rel, filler} <- edits do
        assert File.read!(Path.join(root, rel)) == filler.(pristine[rel], "10"), rel
      end

      for rel <- scribbled do
        expected = if rel =~ "09_", do: restored[rel], else: "// scribble\n"
        assert File.read!(Path.join(root, rel)) == expected, rel
      end

      assert output =~ "assets/koans/drills/09_badge.svelte"
      assert output =~ "assets/js/m.ts"
    end

    test "reset names the typescript markers when one is missing", %{root: root} do
      seed(root)
      run_task(Mix.Tasks.Koans.Gen, ["--root", root])
      path = Path.join(root, "assets/js/m.ts")
      File.write!(path, path |> File.read!() |> String.replace("  // <<< 09\n", ""))

      error =
        assert_raise Mix.Error, ~r/assets\/js\/m.ts: line 2: \/\/ >>> 09 never closed/, fn ->
          Mix.Tasks.Koans.Reset.run(["09", "--root", root])
        end

      assert error.message =~ "between a line // >>> 09 and a line // <<< 09"
      refute error.message =~ "# >>>"
    end

    test "cold strips the steps from both koan files of the chapter", %{root: root} do
      seed(root)
      run_task(Mix.Tasks.Koans.Gen, ["--root", root])

      output = run_task(Mix.Tasks.Koans.Cold, ["09", "--root", root])

      assert File.read!(Path.join(root, "assets/koans/09_t.test.ts")) =~
               ~s|test("Implement it.", () => {|

      assert File.read!(Path.join(root, "test/koans/09_t_test.exs")) =~
               ~s|koan "Implement it." do|

      assert output =~ "assets/koans/09_t.test.ts is cold"
      assert output =~ "test/koans/09_t_test.exs is cold"
      assert File.read!(Path.join(root, "assets/koans/10_t.test.ts")) =~ "1. Do it."
    end
  end
end
