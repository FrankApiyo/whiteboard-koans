defmodule Verify.TsSourceCheckTest do
  use ExUnit.Case, async: true

  alias Koans.Ts.SourceCheck

  @lib "source/assets/js/geometry.ts"
  @koan "source/assets/koans/02_shapes.test.ts"
  @svelte "source/assets/svelte/Badge.svelte"

  defp errors(text, path, opts \\ []) do
    assert {:error, list} = SourceCheck.check(text, path, opts)
    list
  end

  defp ts_block(header, body \\ "  return px >= r.x") do
    "export function contains(r: Rect, px: number): boolean {\n" <>
      "  // >>> answer #{header}\n#{body}\n  // <<<\n}\n"
  end

  defp koan_text(tests) do
    ~s|/*\nLesson.\n*/\nimport { test } from "@koans/runtime"\n\n| <> tests
  end

  defp in_test(body), do: koan_text(~s|test("A.", () => {\n#{body}\n})\n|)

  @svelte_text """
  <script lang="ts">
    let { n }: { n: number } = $props()
    function label(): string {
      // >>> answer 03: label
      return `#${n}`
      // <<<
    }
  </script>

  <!-- >>> answer 03: badge -->
  <span>{label()}</span>
  <!-- <<< -->
  <style>
    span { color: red; }
  </style>
  """

  test "clean typescript, koan and svelte files are ok" do
    assert SourceCheck.check(ts_block("02: hit test"), @lib, chapters: ["02"]) == :ok

    koan =
      koan_text("""
      test("Area is width times height.", () => {
        const { w } = r
        expect(area(r)).toBe(_a(6))
        expect(`${w}`).not.toBe("")
      }, { exercises: "02: hit test" })
      """)

    assert SourceCheck.check(koan, @koan) == :ok

    assert SourceCheck.check(@svelte_text, @svelte,
             chapters: ["03"],
             exercised: [{"03", "03: badge"}]
           ) == :ok
  end

  test "malformed and stub markers" do
    assert "#{@lib}:2: malformed answer marker" in errors(ts_block("two: x"), @lib)

    assert "#{@lib}:2: TypeScript has no stub marker" in errors(
             ts_block("02: f | stub: function f()"),
             @lib
           )
  end

  test "unpaired and mismatched markers" do
    text = "// >>> answer 02: a\nx\n// >>> answer 02: b\ny\n// <<<\n// <<<\n"
    list = errors(text, @lib)
    assert "#{@lib}:3: nested answer marker" in list
    assert "#{@lib}:6: unmatched answer marker" in list

    mismatched = "// >>> answer 02: a\nx\n<!-- <<< -->\n"
    assert "#{@lib}:3: closing marker does not match its opening" in errors(mismatched, @lib)
  end

  test "a // marker outside <script>" do
    text = ~s|<script lang="ts">\n</script>\n\n<p>\n  // >>> answer 03: a\n  x\n  // <<<\n</p>\n|
    assert "#{@svelte}:5: // marker outside <script>" in errors(text, @svelte)
  end

  test "a markup marker inside <script>, <style> or a script file" do
    text = """
    <script lang="ts">
      <!-- >>> answer 03: a -->
      let x = 1
      <!-- <<< -->
    </script>
    <style>
      <!-- >>> answer 03: b -->
      p {}
      <!-- <<< -->
    </style>
    """

    list = errors(text, @svelte)
    assert "#{@svelte}:2: markup marker inside <script>" in list
    assert "#{@svelte}:7: markup marker inside <style>" in list

    ts = "<!-- >>> answer 02: a -->\nx\n<!-- <<< -->\n"
    assert "#{@lib}:1: markup marker in a script file" in errors(ts, @lib)
  end

  test "a marker not on its own line" do
    text = ~s|<script lang="ts">\n</script>\n<p>x</p> <!-- >>> answer 03: a -->\n|
    assert "#{@svelte}:3: markup marker not on its own line" in errors(text, @svelte)
    assert "#{@lib}:1: // marker not on its own line" in errors("f() // >>> answer 02: a\n", @lib)
  end

  for path <- ~w(source/assets/js/types.ts source/assets/js/live.ts source/assets/js/shapes.d.ts
                 source/assets/test/support/fake_canvas.ts source/assets/js/app.js) do
    test "never a blank: #{path}" do
      path = unquote(path)
      assert "#{path}:2: marker in a never-a-blank file" in errors(ts_block("02: x"), path)
    end
  end

  test "a marker around a type or interface declaration" do
    for line <- ["export type Shape = Rect | Circle", "interface Point {", "type P<T> = T"] do
      text = "// >>> answer 02: shapes\n#{line}\n// <<<\n"
      assert "#{@lib}:1: marker around a type or interface declaration" in errors(text, @lib)
    end
  end

  test "a default that does not wrap a whole function body" do
    assert SourceCheck.check(ts_block("02: f | default: false"), @lib) == :ok

    text = """
    export function f(): number {
      const a = 1
      // >>> answer 02: f | default: 0
      return a
      // <<<
    }
    """

    assert "#{@lib}:3: default marker does not wrap a whole function body" in errors(text, @lib)

    markup =
      ~s|<script lang="ts">\n</script>\n<!-- >>> answer 03: a \| default: 1 -->\nx\n<!-- <<< -->\n|

    assert "#{@svelte}:3: default is not allowed on a markup marker" in errors(markup, @svelte)
  end

  test "a duplicate tag in the file or across source" do
    one = "export function a(): number {\n  // >>> answer 02: dup\n  return 1\n  // <<<\n}\n"
    two = String.replace(one, "a()", "b()")
    list = errors(one <> two, @lib)
    assert "#{@lib}:2: duplicate answer tag 02: dup" in list
    assert "#{@lib}:7: duplicate answer tag 02: dup" in list

    text = ts_block("02: hit test")
    assert SourceCheck.check(text, @lib, tag_counts: %{"02: hit test" => 1}) == :ok

    assert errors(text, @lib, tag_counts: %{"02: hit test" => 2}) == [
             "#{@lib}:2: duplicate answer tag 02: hit test"
           ]
  end

  test "a tag naming a chapter with no koan file" do
    assert errors(ts_block("02: hit test"), @lib, chapters: ["01"]) == [
             "#{@lib}:2: answer tag names chapter 02 with no koan file"
           ]
  end

  test "a markup or defaulted tag that no koan of its chapter exercises" do
    for exercised <- [[], [{"04", "03: badge"}]] do
      assert errors(@svelte_text, @svelte, exercised: exercised) == [
               "#{@svelte}:10: no koan of chapter 03 names 03: badge in exercises"
             ]
    end

    assert errors(ts_block("02: f | default: false"), @lib, exercised: []) == [
             "#{@lib}:2: no koan of chapter 02 names 02: f in exercises"
           ]

    assert SourceCheck.check(ts_block("02: f"), @lib, exercised: []) == :ok
  end

  test "a generated blank line over 98 columns" do
    tag = String.duplicate("x", 81)
    assert String.length(~s[  __blank("02: #{tag}");]) == 99

    assert errors(ts_block("02: #{tag}"), @lib) == [
             "#{@lib}:2: generated blank is 99 columns, over 98: shorten the tag"
           ]
  end

  test "a value blank outside a test body" do
    assert errors("export const x = _a(1)\n", @lib) == [
             "#{@lib}:1: value blank outside a test body"
           ]

    assert errors(koan_text("const y = _a(2)\n"), @koan) == [
             "#{@koan}:6: value blank outside a test body"
           ]
  end

  test "a value blank in a comment or a string" do
    text = in_test(~s|  // try _a(1)\n  expect("_a(2)").toBe(1)|)
    list = errors(text, @koan)
    assert "#{@koan}:7: value blank in a comment" in list
    assert "#{@koan}:8: value blank in a string" in list
  end

  test "a value blank in a destructuring target" do
    assert errors(in_test("  const [a, _a(b)] = pair"), @koan) == [
             "#{@koan}:7: value blank in a destructuring target"
           ]
  end

  test "a value blank on a line with .not., !== or !=" do
    text =
      in_test("  expect(1).not.toBe(_a(2))\n  expect(a !== _a(2)).toBe(true)\n  f(a != _a(1))")

    list = errors(text, @koan)

    for line <- 7..9,
        do: assert("#{@koan}:#{line}: value blank compared with != or under .not" in list)
  end

  test "a value blank inside a template literal" do
    assert errors(in_test("  expect(s).toBe(`a${_a(1)}`)"), @koan) == [
             "#{@koan}:7: value blank inside a template literal"
           ]
  end

  test "a nested value blank" do
    assert errors(in_test("  expect(_a(_a(1))).toBe(1)"), @koan) == ["#{@koan}:7: nested _a("]
  end

  test "a test( that is not top-level or has no one-line double-quoted meditation" do
    text =
      koan_text("""
      test('Single.', () => {})
      describe("group", () => {
        test("Nested.", () => {})
      })
      test(
        "Split.", () => {})
      describe("flat", () => {
      test("Flat.", () => {})
      })
      """)

    list = errors(text, @koan)
    shape = "test( must be top-level with a one-line double-quoted meditation"
    for line <- [6, 8, 10, 13], do: assert("#{@koan}:#{line}: #{shape}" in list)
  end

  test "test( lines that differ from the koans the file registers" do
    text =
      ~s|/*\nWrite koans like this:\ntest("Example.", () => {})\n*/\n\n| <>
        ~s|test("Real.", () => {})\n|

    assert errors(text, @koan) == [
             ~s|#{@koan}:1: file has 2 lines starting test(" but registers 1 koans|
           ]
  end

  test "a meditation with regex metacharacters" do
    text =
      koan_text(~s|test("Why (and how)? [x]", () => {})\ntest("Fine. Dots are ok.", () => {})\n|)

    assert errors(text, @koan) == [
             "#{@koan}:6: meditation has regex metacharacters: ( ) ? [ ]"
           ]
  end

  test "duplicate meditations, also once the steps are stripped" do
    text =
      koan_text("""
      test("Same.", () => {})
      test("Same.", () => {})
      test("Steps. 1. A.", () => {})
      test("Steps. 1. B.", () => {})
      """)

    assert errors(text, @koan) == [
             "#{@koan}:7: duplicate meditation",
             "#{@koan}:9: duplicate meditation"
           ]
  end

  test ~s|a component without <script lang="ts">| do
    message = ~s|component has no <script lang="ts">|
    no_lang = "<p>hi</p>\n<script>\n  let x = 1\n</script>\n"
    assert errors(no_lang, @svelte) == ["#{@svelte}:2: #{message}"]
    assert errors("<p>hi</p>\n", @svelte) == ["#{@svelte}:1: #{message}"]
  end

  test "a code blank that declares a binding used outside it" do
    used_after = ts_block("02: area", "  const w = r.w") <> "\n"
    used_after = String.replace(used_after, "  // <<<\n}", "  // <<<\n  return w > 0\n}")

    assert errors(used_after, @lib) == ["#{@lib}:2: code blank declares w, used outside it"]

    top_level = "// >>> answer 02: helper\nfunction helper() {}\n// <<<\nhelper()\n"
    assert errors(top_level, @lib) == ["#{@lib}:1: code blank declares helper, used outside it"]

    own_scope = ts_block("02: area", "  const w = r.w\n  return w > 0")
    other = "\nexport function width(r: Rect): number {\n  const w = r.w\n  return w\n}\n"
    assert SourceCheck.check(own_scope <> other, @lib) == :ok
  end

  test "context counts tags in both languages and collects exercises" do
    files = [
      {"assets/js/a.ts", ts_block("02: hit test")},
      {"lib/easel/a.ex", "# >>> answer 02: hit test\nx\n# <<<\n"},
      {"assets/koans/03_x.test.ts",
       ~s|test("A.", () => {}, { exercises: ["03: badge", "03: other"] })\n| <>
         ~s|test("B.", () => {}, { exercises: "03: third" })\n|}
    ]

    assert SourceCheck.context(files) == [
             tag_counts: %{"02: hit test" => 2},
             exercised: [{"03", "03: badge"}, {"03", "03: other"}, {"03", "03: third"}]
           ]
  end
end
