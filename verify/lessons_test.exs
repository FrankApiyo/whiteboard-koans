defmodule Verify.LessonsTest do
  use ExUnit.Case, async: true

  @root File.cwd!()
  @ex_koan ~r/^\s*koan\s+"/m
  @ts_koan ~r/^test\("/m

  defp ex_sources, do: Path.wildcard(Path.join(@root, "source/test/koans/[0-9][0-9]_*_test.exs"))
  defp ts_sources, do: Path.wildcard(Path.join(@root, "source/assets/koans/[0-9][0-9]_*.test.ts"))
  defp sources, do: ex_sources() ++ ts_sources()
  defp nn(path), do: path |> Path.basename() |> String.slice(0, 2)
  defp chapters, do: sources() |> Enum.map(&nn/1) |> Enum.uniq()

  defp pictures do
    for path <- sources(),
        [_, svg] <- Regex.scan(~r/^\s*Picture: (lessons\/svg\/\S+\.svg)/m, File.read!(path)),
        do: {nn(path), svg}
  end

  defp section(html, nn) do
    [_, body] = Regex.run(~r/<section class="chapter" id="ch#{nn}">(.*?)<\/section>/s, html)
    body
  end

  defp fixture_root(files) do
    root = Path.join(System.tmp_dir!(), "lessons_fixture_#{System.unique_integer([:positive])}")

    for {rel, text} <- files do
      File.mkdir_p!(Path.dirname(Path.join(root, rel)))
      File.write!(Path.join(root, rel), text)
    end

    on_exit(fn -> File.rm_rf!(root) end)
    root
  end

  setup_all do
    {:ok, html: Koans.Lessons.build(@root)}
  end

  test "the page has one section per chapter", %{html: html} do
    assert ex_sources() != [] and ts_sources() != []
    sections = Regex.scan(~r/<section class="chapter" id="ch\d\d"/, html)
    assert length(sections) == length(chapters())
  end

  test "every picture named in a lesson exists and is inlined", %{html: html} do
    for {nn, svg} <- pictures() do
      assert File.exists?(Path.join(@root, svg)), "#{svg} missing"

      assert html =~ ~r/<figure class="fig fig#{nn}(?:-\d)?" id="fig-#{nn}(?:-\d)?">\s*<svg/,
             "#{svg} not inlined"
    end
  end

  test "inlined svgs cannot clash and the page loads nothing external", %{html: html} do
    ids = Regex.scan(~r/\sid="([^"]+)"/, html) |> Enum.map(&List.last/1)
    assert ids == Enum.uniq(ids)
    refute html =~ ~r/(src|href)="https?:/
    refute html =~ "<script"
    refute html =~ ~r/\n\s*text \{/
  end

  test "every url(#x) and href=\"#x\" points at an id on the page", %{html: html} do
    ids = Regex.scan(~r/\sid="([^"]+)"/, html) |> Enum.map(&List.last/1) |> MapSet.new()
    refs = Regex.scan(~r/url\(#([^)]+)\)|href="#([^"]+)"/, html)

    for ref <- refs, target = ref |> tl() |> Enum.find(&(&1 != "")) do
      assert target in ids, "#{target} has no matching id"
    end
  end

  test "every chapter title is a short sentence of at most five words", %{html: html} do
    titles = Regex.scan(~r/<h2><span class="num">\d\d<\/span> ([^<]+)<\/h2>/, html)
    assert length(titles) == length(chapters())

    for [_, title] <- titles do
      assert length(String.split(title)) <= 5, "#{title} is not a short title"
    end
  end

  test "the files list is rendered, not folded into the text", %{html: html} do
    assert html =~ "<h3>Files this chapter touches</h3>"
    assert html =~ ~s(<ul class="files">)
    assert html =~ "<li><code>lib/easel/hello.ex</code>: Easel.Hello.greet/1</li>"
    assert html =~ "<li><code>assets/js/hello.ts</code>: greet</li>"
    refute html =~ "Files this chapter touches\n  - "
    refute html =~ "<p>- lib/"
    refute html =~ "<p>- assets/"
  end

  test "lessons_page_orders_ts_before_ex_in_a_chapter", %{html: html} do
    ch00 = section(html, "00")
    assert ch00 =~ "<h2><span class=\"num\">00</span> About these koans</h2>"
    {ts, _} = :binary.match(ch00, "assets/js/hello.ts")
    {ex, _} = :binary.match(ch00, "lib/easel/hello.ex")
    assert ts < ex

    root =
      fixture_root(%{
        "source/test/koans/07_aaa_test.exs" => ex_lesson("Elixir side. Server body."),
        "source/assets/koans/07_zzz.test.ts" => ts_lesson("Typed side. Client body."),
        "source/test/koans/08_only_test.exs" => ex_lesson("Only Elixir. Its body.")
      })

    fixture = Koans.Lessons.build(root)
    ch07 = section(fixture, "07")
    assert ch07 =~ "<h2><span class=\"num\">07</span> Typed side</h2>"
    assert ch07 =~ "<p>Client body.</p>"
    assert ch07 =~ "<p>Elixir side. Server body.</p>"
    {client, _} = :binary.match(ch07, "TypeScript and Svelte")
    {server, _} = :binary.match(ch07, "<h3 class=\"kind\">Elixir</h3>")
    assert client < server
    assert section(fixture, "08") =~ "<h2><span class=\"num\">08</span> Only Elixir</h2>"
    refute section(fixture, "08") =~ ~s(class="kind")
  end

  defp ex_lesson(text) do
    ~s'''
    defmodule Koans.ChNN.FixtureTest do
      use Koans

      @moduledoc ~S"""
      #{text}

      API you'll use
        Mod.fun/1
      Picture: none for this chapter.
      """
    end
    '''
  end

  defp ts_lesson(text) do
    "/*\n#{text}\n\nAPI you'll use\n  - fn()\n\nPicture: none for this chapter.\n*/\n" <>
      ~s|import { test } from "@koans/runtime"\n|
  end

  describe "escaping" do
    @ex_fixture ~S'''
    defmodule Koans.Ch99.FixtureTest do
      use Koans

      @moduledoc ~S"""
      Files this chapter touches
        - lib/a.ex: A.f/1 <b>&

      Title <b>&.
      Body <b>& text.

          code <b>& here

      API you'll use
        Mod.fun/1  <b>&
      Picture: none for this chapter.
      """
    end
    '''

    @ts_fixture ~S'''
    /*
    Files this chapter touches
      - assets/js/a.ts: f <i>&

    Typed <i>&. Body <i>& text.

        const x = a < b && c

    API you'll use
      - g() <i>&

    Picture: none for this chapter.
    */
    import { test } from "@koans/runtime"
    '''

    setup do
      root =
        fixture_root(%{
          "source/test/koans/99_fixture_test.exs" => @ex_fixture,
          "source/assets/koans/98_fixture.test.ts" => @ts_fixture
        })

      {:ok, fixture_html: Koans.Lessons.build(root)}
    end

    test "title, paragraph, code block and API line are escaped", %{fixture_html: html} do
      assert html =~ "Title &lt;b&gt;&amp;</h2>"
      assert html =~ "<li><code>lib/a.ex</code>: A.f/1 &lt;b&gt;&amp;</li>"
      assert html =~ "<p>Body &lt;b&gt;&amp; text.</p>"
      assert html =~ "<pre>code &lt;b&gt;&amp; here</pre>"
      assert html =~ "Mod.fun/1  &lt;b&gt;&amp;</pre>"
      assert html =~ ~s(&lt;b&gt;&amp;</a></li>)
      refute html =~ "<b>"
    end

    test "a TypeScript lesson is escaped the same way", %{fixture_html: html} do
      assert html =~ "<h2><span class=\"num\">98</span> Typed &lt;i&gt;&amp;</h2>"
      assert html =~ "<li><code>assets/js/a.ts</code>: f &lt;i&gt;&amp;</li>"
      assert html =~ "<p>Body &lt;i&gt;&amp; text.</p>"
      assert html =~ "<pre>const x = a &lt; b &amp;&amp; c</pre>"
      assert html =~ "- g() &lt;i&gt;&amp;</pre>"
      refute html =~ "<i>"
    end
  end

  test "regenerating changes nothing", %{html: html} do
    assert Koans.Lessons.build(@root) == html
    assert File.read!(Path.join(@root, "lessons/index.html")) == html
  end

  describe "README" do
    defp readme, do: File.read!(Path.join(@root, "README.md"))

    defp koan_counts do
      sources()
      |> Enum.group_by(&nn/1)
      |> Map.new(fn {nn, paths} ->
        {nn, paths |> Enum.map(&length(Regex.scan(koan_line(&1), File.read!(&1)))) |> Enum.sum()}
      end)
    end

    defp koan_line(path), do: if(String.ends_with?(path, ".ts"), do: @ts_koan, else: @ex_koan)

    defp morning_rows do
      for [_, chapters, total] <- Regex.scan(~r/^\| \d \| (.+) \| (\d+) \|$/m, readme()) do
        counts = for [_, nn, n] <- Regex.scan(~r/(\d\d) [^|(]+\((\d+)\)/, chapters), do: {nn, n}
        {counts, String.to_integer(total)}
      end
    end

    @tag :readme_counts
    test "every total in the README is the number of koans" do
      total = koan_counts() |> Map.values() |> Enum.sum()
      assert total > 0
      stated = Regex.scan(~r/(\d+) koans/, readme()) ++ Regex.scan(~r/of (\d+) koans/, readme())
      assert stated != []
      assert Enum.uniq(for [_, n] <- stated, do: String.to_integer(n)) == [total]
    end

    @tag :readme_counts
    test "the README names the number of chapters" do
      assert Regex.scan(~r/(\d+) chapters/, readme()) == [
               ["#{length(chapters())} chapters", "#{length(chapters())}"]
             ]
    end

    @tag :readme_counts
    test "the mornings table counts every chapter's koans" do
      rows = morning_rows()
      assert length(rows) == 6

      table =
        Map.new(Enum.flat_map(rows, &elem(&1, 0)), fn {nn, n} -> {nn, String.to_integer(n)} end)

      assert table == koan_counts()

      for {counts, total} <- rows do
        assert total == Enum.sum(for {_, n} <- counts, do: String.to_integer(n))
      end
    end

    test "every course command the README names exists" do
      named =
        ~r/mix\s+((?:koans|easel)\.[a-z_]+)/ |> Regex.scan(readme()) |> Enum.map(&List.last/1)

      assert "easel.export" in named
      assert "koans.lessons" in named
      assert readme() =~ "mix koans\n"

      for task <- Enum.uniq(["koans" | named]) do
        path = Path.join(@root, "course/lib/mix/tasks/#{task}.ex")
        assert File.exists?(path), "mix #{task}"
        assert File.read!(path) =~ "use Mix.Task", "mix #{task}"
      end
    end

    test "the footers in the README are the course's" do
      [{ts_blank, _}] = line_of(learner("assets/js/hello.ts"), ~s|__blank("00: greet");|)
      [{ts_koan, _} | _] = line_of(learner("assets/koans/00_about_koans.test.ts"), "test(")
      [{ex_value, _} | _] = line_of(learner("test/koans/00_about_koans_test.exs"), "== __")

      assert readme() =~ "Write:          assets/js/hello.ts:#{ts_blank}  (00: greet)"
      assert readme() =~ "Exercised by:   assets/koans/00_about_koans.test.ts:#{ts_koan}"
      assert readme() =~ "Meditate on test/koans/00_about_koans_test.exs:#{ex_value}"
      assert readme() =~ "Replace __blank() with the code the meditation describes."
      assert readme() =~ "Replace __ with the value that makes this true."
    end

    defp learner(rel) do
      Koans.Gen.Project.content(%{path: Path.join([@root, "source", rel]), rel: rel}, :learner)
    end

    defp line_of(text, needle) do
      for {line, n} <- text |> String.split("\n") |> Enum.with_index(1),
          String.contains?(line, needle),
          do: {n, line}
    end
  end
end
