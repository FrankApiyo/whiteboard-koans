Code.require_file("support/course_runner.exs", __DIR__)

defmodule Verify.ExportTest do
  use ExUnit.Case, async: false

  alias Koans.{Export, Gen}
  alias Koans.Gen.Project
  alias Verify.CourseRunner

  @repo File.cwd!()
  @fixture Path.join(@repo, "verify/fixtures/export")
  @templates Path.join(@repo, "course/export")
  @git_env [
    {"GIT_CONFIG_GLOBAL", "/dev/null"},
    {"GIT_AUTHOR_NAME", "Test"},
    {"GIT_AUTHOR_EMAIL", "test@example.com"},
    {"GIT_COMMITTER_NAME", "Test"},
    {"GIT_COMMITTER_EMAIL", "test@example.com"}
  ]
  @traces [
    "Koans",
    "koans",
    "KOANS_",
    "__blank",
    "# >>>",
    "# <<<",
    "<%!-- >>>",
    "<%!-- <<<",
    "// >>>",
    "// <<<",
    "<!-- >>>",
    "<!-- <<<",
    "/* >>>",
    "/* <<<",
    "course",
    "solutions"
  ]

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "easel_export_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp clone!(from, to) do
    File.mkdir_p!(Path.dirname(to))
    {_, 0} = System.cmd("cp", ["-c", "-R", from, to])
  end

  defp regions(text, syntax) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, number} ->
      case syntax.parse_region(line) do
        nil -> []
        %{kind: kind} -> [{kind, number}]
      end
    end)
    |> Enum.chunk_every(2)
    |> Enum.map(fn [{:open, from}, {:close, to}] -> %{from: from, to: to} end)
  end

  defp answer_blocks(text, syntax) do
    text
    |> syntax.scan()
    |> Enum.chunk_every(2)
    |> Enum.map(fn [{from, %{kind: :open}}, {to, %{kind: :close}}] -> %{from: from, to: to} end)
  end

  defp keep_markers_and_fill(learner, source, syntax) do
    source_lines = String.split(source, "\n")

    learner
    |> regions(syntax)
    |> Enum.zip(answer_blocks(source, syntax))
    |> Enum.reverse()
    |> Enum.reduce(String.split(learner, "\n"), fn {mine, theirs}, lines ->
      answer = Enum.slice(source_lines, theirs.from, theirs.to - theirs.from - 1)
      Enum.take(lines, mine.from) ++ answer ++ Enum.drop(lines, mine.to - 1)
    end)
    |> Enum.join("\n")
  end

  defp write_learner!(root, fill?) do
    for file <- Project.source_files(root) do
      learner = Project.content(file, :learner)
      fill_this? = fill?.(file.rel) and Project.text?(file) and not Project.koan_file?(file.rel)
      syntax = Gen.syntax(Project.render_opts(file))

      text =
        if fill_this?,
          do: keep_markers_and_fill(learner, File.read!(file.path), syntax),
          else: learner

      target = Path.join(root, file.rel)
      File.mkdir_p!(Path.dirname(target))
      File.write!(target, text)
    end
  end

  defp fixture_root(fill?) do
    root = Path.join(tmp_dir(), "root")
    File.cp_r!(Path.join(@fixture, "app"), root)
    File.cp_r!(Path.join(@fixture, "source"), Path.join(root, "source"))
    write_learner!(root, fill?)
    root
  end

  defp filled_fixture_root, do: fixture_root(fn _rel -> true end)

  defp export(root, target), do: Export.run(root, target, git_env: @git_env)

  defp files_under(dir) do
    for path <- Path.wildcard(Path.join(dir, "**/*"), match_dot: true),
        File.regular?(path),
        not String.contains?(path, "/.git/"),
        do: Path.relative_to(path, dir)
  end

  defp read(target, rel), do: File.read!(Path.join(target, rel))

  defp refute_traces!(target) do
    for path <- files_under(target),
        path != "README.md",
        not String.starts_with?(path, "assets/vendor/"),
        Path.extname(path) in ~w(.ex .exs .heex .ts .js .mjs .svelte .css .json .yml .lock) or
          path in ~w(.formatter.exs .gitignore) do
      text = read(target, path)
      for needle <- @traces, do: refute(text =~ needle, "#{path} still has #{inspect(needle)}")
      refute text =~ ~r/(?<![A-Za-z0-9_])__\(/, "#{path} still has a blank call"
    end
  end

  describe "refusals" do
    test "export_refuses_blanks" do
      root = fixture_root(&(not String.starts_with?(&1, "lib/")))
      target = Path.join(tmp_dir(), "out")

      assert {:error, message} = export(root, target)
      assert message =~ "lib/demo.ex:"
      assert message =~ ~S[__("01: add")]
      assert length(Regex.scan(~r/^\s+\S+\.ex:\d+/m, message)) == 3
      refute File.exists?(target)
    end

    test "export_refuses_a_ts_blank" do
      root = fixture_root(&(not String.starts_with?(&1, "assets/js/")))
      target = Path.join(tmp_dir(), "out")

      assert read(root, "lib/demo.ex") =~ "a + b", "precondition: Elixir answers filled"
      assert read(root, "assets/svelte/List.svelte") =~ "<li>{row}</li>"

      assert {:error, message} = export(root, target)
      assert message =~ "2 blank(s) left"
      assert message =~ ~s[assets/js/geo.ts:8  __blank("02: area");]
      assert message =~ ~s[assets/js/geo.ts:14  return __blank("03: label", "");]
      refute File.exists?(target)
    end

    test "a markup blank in a component is refused" do
      root = fixture_root(&(&1 != "assets/svelte/List.svelte"))

      assert {:error, message} = export(root, Path.join(tmp_dir(), "out"))
      assert message =~ ~s[assets/svelte/List.svelte:16  {__blank("05: rows", "")}]
      assert message =~ ~s[assets/svelte/List.svelte:9  __blank("05: count");]
    end

    test "a blank anywhere in the copied trees is refused" do
      root = filled_fixture_root()
      File.write!(Path.join(root, "e2e/demo.spec.ts"), ~s|test("x", () => __blank("09: e2e"))\n|)
      File.write!(Path.join(root, "config/config.exs"), ~s|import Config\nx = __("09: key")\n|)

      assert {:error, message} = export(root, Path.join(tmp_dir(), "out"))
      assert message =~ "2 blank(s) left"
      assert message =~ "e2e/demo.spec.ts:1"
      assert message =~ "config/config.exs:2"
    end

    test "export_refuses_existing_target" do
      root = filled_fixture_root()
      target = tmp_dir()
      File.write!(Path.join(target, "keep.txt"), "mine")

      assert {:error, message} = export(root, target)
      assert message =~ "already exists"
      assert read(target, "keep.txt") == "mine"
      assert files_under(target) == ["keep.txt"]
      refute File.exists?(Path.join(target, ".git"))
    end

    test "a blank in a file the export leaves out does not block it" do
      root = filled_fixture_root()

      left_out = %{
        "lib/easel/hello.ex" =>
          ~s|defmodule Easel.Hello do\n  def greet(_), do: __("00: g")\nend\n|,
        "test/easel/hello_test.exs" => "defmodule Easel.HelloTest do\nend\n",
        "assets/js/hello.ts" =>
          ~s|export function greet(): string {\n  __blank("00: greet");\n}\n|,
        "assets/test/hello.test.ts" => ~s|import { greet } from "../js/hello"\n|
      }

      for {rel, text} <- left_out do
        File.mkdir_p!(Path.dirname(Path.join(root, rel)))
        File.write!(Path.join(root, rel), text)
      end

      target = Path.join(tmp_dir(), "out")

      assert {:ok, _} = export(root, target)
      for rel <- Map.keys(left_out), do: refute(File.exists?(Path.join(target, rel)), rel)
      assert File.exists?(Path.join(target, "test/easel/shapes_test.exs"))
    end

    test "a failing git commit leaves nothing at the target" do
      root = filled_fixture_root()
      target = Path.join(tmp_dir(), "out")

      no_identity = [
        {"GIT_CONFIG_GLOBAL", "/dev/null"},
        {"GIT_CONFIG_SYSTEM", "/dev/null"},
        {"GIT_CONFIG_COUNT", "1"},
        {"GIT_CONFIG_KEY_0", "user.useConfigOnly"},
        {"GIT_CONFIG_VALUE_0", "true"},
        {"GIT_AUTHOR_NAME", nil},
        {"GIT_AUTHOR_EMAIL", nil},
        {"GIT_COMMITTER_NAME", nil},
        {"GIT_COMMITTER_EMAIL", nil},
        {"EMAIL", nil}
      ]

      assert {:error, message} = Export.run(root, target, git_env: no_identity)
      assert message =~ "git commit failed for #{target}:"
      refute message =~ ".partial-"
      assert Path.wildcard(target <> "*") == []
    end

    test "an unclosed course block leaves nothing at the target" do
      for {rel, text} <- [
            {"lib/broken.ex", "defmodule B do\n  # >>> course\nend\n"},
            {"assets/js/broken.ts", "// >>> course\nexport const x = 1\n"}
          ] do
        root = filled_fixture_root()
        File.write!(Path.join(root, rel), text)
        target = Path.join(tmp_dir(), "out")

        assert {:error, message} = export(root, target)
        assert message =~ "#{rel}: course block never closed"
        assert Path.wildcard(target <> "*") == []
      end
    end

    test "a file that does not parse leaves nothing at the target" do
      root = filled_fixture_root()
      File.write!(Path.join(root, "lib/broken.ex"), "defmodule B do\n  def x(\nend\n")
      target = Path.join(tmp_dir(), "out")

      assert {:error, message} = export(root, target)
      assert message =~ "export failed"
      assert Path.wildcard(target <> "*") == []
    end

    test "a function named like a blank is not refused" do
      root = filled_fixture_root()

      File.write!(
        Path.join(root, "lib/schema.ex"),
        "defmodule S do\n  def x, do: __schema__(:fields)\nend\n"
      )

      File.write!(
        Path.join(root, "assets/js/names.ts"),
        "export const my__blank = (x: number) => x\nexport const y = my__blank(1)\n"
      )

      assert {:ok, _} = export(root, Path.join(tmp_dir(), "out"))
    end
  end

  describe "stripping" do
    setup do
      root = filled_fixture_root()
      File.mkdir_p!(Path.join(root, "course/lib"))
      File.write!(Path.join(root, "course/lib/koans.ex"), "defmodule Koans, do: nil\n")
      File.mkdir_p!(Path.join(root, "assets/node_modules/x"))
      File.write!(Path.join(root, "assets/node_modules/x/index.js"), "module.exports = 1\n")

      for dir <- ~w(solutions lessons verify docs _verify spike) do
        File.mkdir_p!(Path.join(root, dir))
        File.write!(Path.join([root, dir, "x.ex"]), "# x\n")
      end

      target = Path.join(tmp_dir(), "out")
      assert {:ok, _} = export(root, target)
      {:ok, target: target, root: root}
    end

    test "export_strips_every_marker_shape", %{target: target, root: root} do
      for {path, needle} <- [
            {"lib/demo.ex", "# >>> 01"},
            {"lib/demo_web.ex", "# >>> course"},
            {"lib/demo_web/page.html.heex", "<%!-- >>> 04 --%>"},
            {"lib/demo_web/live.ex", "<%!-- <<< 05 --%>"},
            {"mix.exs", "# >>> course"},
            {"config/config.exs", "# >>> course"},
            {"lib/demo.ex", "import Enum, warn: false"}
          ] do
        assert read(root, path) =~ needle, "precondition: #{path} lacks #{needle}"
      end

      refute_traces!(target)

      lib = read(target, "lib/demo.ex")
      assert lib =~ "  import Enum\n"
      assert lib =~ "a + b"
      assert lib =~ "def kind(1), do: :one"
      assert lib =~ "send(self(), {:note, x})"
      assert read(target, "lib/demo_web/page.html.heex") =~ "<p>{@preview}</p>"
      assert read(target, "lib/demo_web/live.ex") =~ "<li :for={n <- @notes}>{n}</li>"
      assert read(target, "test/support/helper.ex") =~ "x * 2"
      assert read(target, "lib/demo_web.ex") =~ "import Phoenix.HTML"
      assert read(target, "config/config.exs") == "import Config\n\nconfig :demo, key: :value\n"
    end

    test "export_strips_every_ts_and_svelte_marker_shape", %{target: target, root: root} do
      for {path, needle} <- [
            {"assets/js/geo.ts", "  // >>> 02\n"},
            {"assets/js/geo.ts", "  // <<< 03\n"},
            {"assets/svelte/List.svelte", "    // >>> 05\n"},
            {"assets/svelte/List.svelte", "  <!-- >>> 05 -->\n"},
            {"assets/svelte/List.svelte", "  <!-- <<< 05 -->\n"},
            {"assets/svelte/List.svelte", "  // >>> course\n"},
            {"assets/test/support/helper.ts", "  // >>> 06\n"},
            {"assets/js/app.js", "// >>> course\n"},
            {"assets/vite.config.mjs", "      // >>> course\n"},
            {"assets/tsconfig.json", "    // >>> course\n"},
            {"assets/css/app.css", "/* >>> course */\n"},
            {"playwright.config.ts", "      // >>> course\n"}
          ] do
        assert read(root, path) =~ needle, "precondition: #{path} lacks #{inspect(needle)}"
      end

      assert read(target, "assets/js/geo.ts") ==
               File.read!(Path.join(@fixture, "source/assets/js/geo.ts"))
               |> String.replace(~r/^ *\/\/ (>>> answer.*|<<<)\n/m, "")

      assert read(target, "assets/svelte/List.svelte") ==
               """
               <script lang="ts">
                 let { rows }: { rows: string[] } = $props()

                 function count(): number {
                   return rows.length
                 }
               </script>

               <ul data-count={count()}>
                 {#each rows as row (row)}
                   <li>{row}</li>
                 {/each}
               </ul>
               """

      assert read(target, "assets/test/support/helper.ts") =~ "\n  return n * 2\n}"

      assert read(target, "assets/js/app.js") ==
               ~s|import { area } from "./geo"\n\nwindow.area = area\n|

      assert read(target, "assets/css/app.css") =~ ~s|@source "../svelte/**/*.svelte";\n\n/* This|

      vite = read(target, "assets/vite.config.mjs")
      assert vite =~ ~s|      "@": ".",\n    },|
      assert vite =~ ~s|      entrypoint: "./js/server.js",\n    }),|
      refute vite =~ "path"

      tsconfig = read(target, "assets/tsconfig.json")

      assert JSON.decode!(tsconfig) == %{
               "compilerOptions" => %{"strict" => true, "noImplicitReturns" => true},
               "include" => ["js/**/*.ts", "svelte/**/*", "test/**/*"]
             }

      assert read(target, "playwright.config.ts") =~ ~s|      MIX_ENV: "e2e",\n    },|
    end

    test "export_copies_only_the_app", %{target: target} do
      files = files_under(target)

      for rel <-
            ~w(lib/demo.ex test/easel_demo_test.exs test/easel/shapes_test.exs
                    test/test_helper.exs config/config.exs mix.lock priv/repo/seeds.exs
                    e2e/demo.spec.ts playwright.config.ts vitest.config.ts package.json
                    package-lock.json assets/svelte.config.js assets/js/geo.ts
                    assets/svelte/List.svelte assets/test/geo.test.ts assets/test/support/helper.ts) do
        assert rel in files, "#{rel} missing"
      end

      for dir <- ~w(course solutions lessons verify source _verify spike docs test/koans
                    assets/koans assets/koans_support assets/node_modules priv/static) do
        refute Enum.any?(files, &String.starts_with?(&1, dir <> "/")), "#{dir}/ was copied"
      end

      for rel <- ~w(assets/vitest.app.config.ts assets/vitest.course.config.ts),
          do: refute(rel in files, "#{rel} was copied")
    end

    test "export_swaps_the_mix_block_and_the_lock", %{target: target} do
      mix = read(target, "mix.exs")
      assert mix =~ ~s|defp elixirc_paths(:test), do: ["lib", "test/support"]|
      assert mix =~ ~s|defp elixirc_paths(_), do: ["lib"]|
      assert mix =~ ~r/preferred_envs: \[\s*precommit: :test\s*\]/
      refute mix =~ "koans"
      refute mix =~ "test_paths"
      refute mix =~ ":e2e"

      lock = read(target, "mix.lock")
      refute lock =~ "koans"
      assert lock =~ ~s("phoenix")
    end

    test "export_rewrites_package_scripts_and_vitest_config", %{target: target} do
      scripts = @templates |> Path.join("package_scripts.json") |> File.read!() |> JSON.decode!()
      assert Map.keys(scripts) |> Enum.sort() == ~w(build check e2e test)

      package = target |> read("package.json") |> JSON.decode!()
      assert package["scripts"] == scripts
      assert package["dependencies"] == %{"phoenix" => "file:./deps/phoenix"}
      assert package["devDependencies"] == %{"vitest" => "^5.1.0"}
      assert package["name"] == "easel"
      assert package["private"] == true
      assert read(target, "package.json") =~ ~s|  "type": "module",\n  "scripts": {\n    "|

      assert JSON.decode!(read(target, "package-lock.json"))["name"] == "easel"

      vitest = read(target, "assets/vitest.config.ts")
      assert vitest == File.read!(Path.join(@templates, "vitest.config.ts"))
      assert vitest =~ ~s|include: ["assets/test/**/*.test.ts"]|
      assert vitest =~ ~s|"assets/test/support/setup.ts"|
      assert read(target, "vitest.config.ts") =~ ~s|from "./assets/vitest.config"|

      app_config = File.read!(Path.join(@repo, "assets/vitest.app.config.ts"))

      for line <- [
            ~s|plugins: [svelte({ configFile: path.join(repo, "assets/svelte.config.js") }), svelteTesting()],|,
            ~s|environment: "jsdom",|,
            ~s|test/support/setup.ts"|
          ] do
        assert app_config =~ line, "the app config no longer has #{line}"
        assert vitest =~ line, "the export's config lacks #{line}"
      end
    end

    test "export_writes_templates_and_one_commit", %{target: target} do
      for path <- ~w(.formatter.exs .gitignore README.md .github/workflows/ci.yml) do
        assert File.exists?(Path.join(target, path)), "#{path} missing"
      end

      gitignore = read(target, ".gitignore")
      for line <- ~w(/node_modules/ /priv/static/* /deps/ /_build/), do: assert(gitignore =~ line)

      {log, 0} = System.cmd("git", ["log", "--format=%an|%s|%b"], cd: target, env: @git_env)
      assert String.trim(log) == "Test|feat: easel whiteboard app|"
      {status, 0} = System.cmd("git", ["status", "--porcelain"], cd: target, env: @git_env)
      assert status == ""
    end

    test "export_writes_ci_steps", %{target: target} do
      ci = read(target, ".github/workflows/ci.yml")
      steps = ~r/^\s+- (?:run|uses): (.+)$/m |> Regex.scan(ci) |> Enum.map(&List.last/1)

      for step <- [
            "actions/checkout@v7",
            "erlef/setup-beam@v1",
            "actions/setup-node@v7",
            "actions/cache@v6",
            "actions/upload-artifact@v7",
            "mix deps.get",
            "npm ci",
            "mix compile --warnings-as-errors",
            "mix format --check-formatted",
            "mix assets.build",
            "mix test",
            "npm test",
            "npx svelte-check --tsconfig assets/tsconfig.json --fail-on-warnings",
            "npx playwright install --with-deps chromium",
            "npm run e2e"
          ] do
        assert step in steps, "ci.yml lacks #{step}"
      end

      index = &Enum.find_index(steps, fn step -> step == &1 end)
      assert index.("mix deps.get") < index.("npm ci")
      assert index.("mix assets.build") < index.("mix test")
      assert ci =~ ~s|elixir-version: "1.19"|
      assert ci =~ ~s|otp-version: "28"|
      assert ci =~ ~s|node-version: "25"|
      assert ci =~ "  e2e:\n"
      refute ci =~ ~r/actions\/\S+@v[1-5]\n/

      for job <- ~w(test e2e) do
        assert ci =~
                 "key: mix-#{job}-${{ runner.os }}-otp${{ steps.beam.outputs.otp-version }}-elixir${{ steps.beam.outputs.elixir-version }}-${{ hashFiles('mix.lock') }}"
      end

      [_test_job, e2e_job] = String.split(ci, "\n  e2e:\n")
      e2e_steps = ~r/^\s+- (?:run|uses): (.+)$/m |> Regex.scan(e2e_job) |> Enum.map(&List.last/1)
      e2e_index = &Enum.find_index(e2e_steps, fn step -> step == &1 end)
      assert e2e_index.("mix compile") < e2e_index.("npm run e2e")
      assert e2e_job =~ "      MIX_ENV: e2e\n"
      assert e2e_job =~ ~r/- uses: actions\/upload-artifact@v7\n\s+if: failure\(\)\n/
      assert e2e_job =~ "path: playwright-report/"
    end

    test "export_formats_what_it_writes", %{target: target} do
      for path <- ~w(mix.exs lib/demo.ex lib/demo_web.ex config/config.exs) do
        text = read(target, path)

        assert text == IO.iodata_to_binary([Code.format_string!(text), "\n"]),
               "#{path} is not formatted"
      end

      refute read(target, "mix.exs") =~ "\n\n\n"
    end
  end

  describe "the exported README matches the code" do
    defp readme, do: File.read!(Path.join(@templates, "README.md"))
    defp source(rel), do: File.read!(Path.join([@repo, "source", rel]))

    test "the course line claims no authorship and names no tool" do
      assert readme() =~ "Built while working through a hands-on course"
      refute readme() =~ ~r/self-written|my course|I wrote|\bAI\b|Claude|koan/i
    end

    test "the README has its sections" do
      for heading <- [
            "## Features",
            "## Run it",
            "## How it is built",
            "## Design decisions",
            "### On Postgres",
            "### In a cluster",
            "## End-to-end tests",
            "## Known limits"
          ],
          do: assert(readme() =~ "\n#{heading}\n", "README lacks #{heading}")

      assert readme() =~ "mix setup"
      assert readme() =~ "mix phx.server"
      assert readme() =~ "npm run e2e"
      assert readme() =~ "<!-- Add a screenshot:"
      assert readme() =~ "keyboard"
    end

    test "the README claims no more than the code does" do
      refute readme() =~ "trusts nothing"
      refute readme() =~ "changes nothing"
      assert readme() =~ "do not commute"
      assert readme() =~ "tombstone"
      assert readme() =~ "no per-board shape cap"
      assert readme() =~ "server-side rate limit"
      assert readme() =~ ~r/and because it traps exits,\s+on shutdown too/
    end

    test "the numbers in the README are the code's" do
      assert readme() =~ "1600 by 1000"
      assert source("lib/easel/shapes/validations.ex") =~ "@width 1600\n  @height 1000"
      assert readme() =~ "2000 points"
      assert source("lib/easel/shapes/pen.ex") =~ "max: 2000"
      assert source("assets/js/types.ts") =~ "MAX_PEN_POINTS = 2000"
      assert readme() =~ "20 times a second"
      assert source("assets/js/outbox.ts") =~ "ms = 50"

      config = File.read!(Path.join(@repo, "config/config.exs"))
      assert readme() =~ "500 ms"
      assert readme() =~ "five idle minutes"
      assert config =~ "save_after: 500, idle_after: :timer.minutes(5)"
    end

    test "the process and message names in the README are the code's" do
      server = source("lib/easel/boards/board_server.ex")
      live = source("lib/easel_web/live/board_live.ex")

      for name <- ~w(Easel.Boards.BoardServer Easel.Boards.Registry Easel.Boards.BoardSupervisor),
          do: assert(readme() =~ "`#{name}`")

      assert server =~ "use GenServer, restart: :transient"
      assert server =~ "Process.flag(:trap_exit, true)"
      assert readme() =~ "`:board_restarted`"
      assert server =~ ":board_restarted"
      assert readme() =~ "`sync_id`"
      assert live =~ "sync_id: sync_id()"
      assert readme() =~ "`broadcast_from`"
      assert live =~ "Phoenix.PubSub.broadcast_from("
      assert readme() =~ ~s|`"board:<slug>"`|
      assert source("lib/easel/boards.ex") =~ ~S|def topic(slug), do: "board:#{slug}"|
    end
  end

  describe "stripping a single text" do
    test "keeps unrelated comments and indentation" do
      text =
        "  # keep me\n    # >>> 07\n    x\n    # <<< 07\n  # >>> course\n  y\n  # <<< course\n"

      assert Export.strip(text, "lib/x.ex") == "  # keep me\n    x\n"
    end

    test "warn: false is stripped from imports and aliases" do
      text =
        "import Mod, warn: false\n  alias A.{B, C}, warn: false\n  alias A, as: X, warn: false\n  import Mod, only: [a: 1], warn: false\n  x = [warn: false]\n"

      assert Export.strip(text, "lib/x.ex") ==
               "import Mod\n  alias A.{B, C}\n  alias A, as: X\n  import Mod, only: [a: 1]\n  x = [warn: false]\n"
    end

    test "script, markup, css and json shapes" do
      assert Export.strip("a\n  // >>> 07\n  b\n  // <<< 07\nc\n", "x.ts") == "a\n  b\nc\n"

      assert Export.strip(
               "<ul>\n  <!-- >>> 07 -->\n  <li />\n  <!-- <<< 07 -->\n</ul>\n",
               "X.svelte"
             ) ==
               "<ul>\n  <li />\n</ul>\n"

      assert Export.strip("a\n/* >>> course */\nb\n/* <<< course */\n", "x.css") == "a\n"

      assert Export.strip(~s|[\n  "a",\n  // >>> course\n  "b"\n  // <<< course\n]\n|, "x.json") ==
               ~s|[\n  "a"\n]\n|
    end

    test "a marker of one language is kept in another" do
      assert Export.strip("x\n# >>> 07\n", "x.ts") == "x\n# >>> 07\n"
      assert Export.strip("x\n// >>> 07\n", "x.ex") == "x\n// >>> 07\n"
    end

    test "an unclosed course block is an error" do
      assert_raise ArgumentError, ~r/course/, fn -> Export.strip("# >>> course\nx\n", "x.ex") end
      assert_raise ArgumentError, ~r/course/, fn -> Export.strip("// >>> course\nx\n", "x.ts") end
    end
  end

  @tag :export_full
  @tag timeout: 900_000
  test "export_is_clean_and_green" do
    root = Path.join(tmp_dir(), "root")

    for rel <-
          ~w(config priv assets e2e mix.exs mix.lock .formatter.exs source course package.json
             package-lock.json vitest.config.ts playwright.config.ts),
        File.exists?(Path.join(@repo, rel)) do
      clone!(Path.join(@repo, rel), Path.join(root, rel))
    end

    File.rm_rf!(Path.join(root, "priv/static"))
    File.rm_rf!(Path.join(root, "course/_build"))
    clone!(Path.join(@repo, "test/test_helper.exs"), Path.join(root, "test/test_helper.exs"))

    for path <- Path.wildcard(Path.join(@repo, "test/easel*")),
        do: clone!(path, Path.join(root, "test/#{Path.basename(path)}"))

    File.ln_s!(Path.join(@repo, "deps"), Path.join(root, "deps"))
    clone!(Path.join(@repo, "_build/test/lib"), Path.join(root, "_build/test/lib"))
    File.rm_rf!(Path.join(root, "_build/test/lib/easel"))
    write_learner!(root, fn _rel -> true end)

    for rel <- ~w(docs AGENTS.md), do: clone!(Path.join(@repo, rel), Path.join(root, rel))

    for rel <- ~w(lib/easel/hello.ex test/easel/hello_test.exs assets/js/hello.ts
                  assets/test/hello.test.ts docs/early-checks.md AGENTS.md),
        do: assert(File.exists?(Path.join(root, rel)), "precondition: #{rel} is in the root")

    target = Path.join(tmp_dir(), "easel")

    env = [
      {"MIX_ENV", "test"},
      {"MIX_DEPS_PATH", Path.join(@repo, "deps")},
      {"MIX_TEST_PARTITION", nil},
      {"KOANS_LIB", nil},
      {"KOANS_DIR", nil},
      {"KOANS_VERIFY", nil},
      {"KOANS_TS_DIR", nil},
      {"KOANS_RESULTS", nil}
    ]

    {out, status} =
      CourseRunner.cmd_mix(["easel.export", target],
        cd: root,
        env: env ++ @git_env,
        stderr_to_stdout: true
      )

    assert status == 0, "mix easel.export failed:\n#{String.slice(out, -3000, 3000)}"

    refute_traces!(target)

    for rel <- ~w(lib/easel/hello.ex test/easel/hello_test.exs assets/js/hello.ts
                  assets/test/hello.test.ts docs/early-checks.md AGENTS.md),
        do: refute(File.exists?(Path.join(target, rel)), "#{rel} was exported")

    app_js = read(target, "assets/js/app.js")
    for leftover <- ["esbuild", "--prefix assets", "user_socket"], do: refute(app_js =~ leftover)
    vite = read(target, "assets/vite.config.mjs")
    refute vite =~ "'"
    refute vite =~ ";\n"
    refute vite =~ "\n    build:"

    {log, 0} = System.cmd("git", ["log", "--format=%s"], cd: target, env: @git_env)
    assert String.trim(log) == "feat: easel whiteboard app"

    clone!(Path.join(@repo, "_build/test/lib"), Path.join(target, "_build/test/lib"))
    File.ln_s!(Path.join(@repo, "deps"), Path.join(target, "deps"))
    # Vite follows a symlinked node_modules to its real path outside the export and then
    # cannot load the testing library's setup file, so the export gets an APFS clone.
    clone!(Path.join(@repo, "node_modules"), Path.join(target, "node_modules"))
    for dep <- ~w(easel koans), do: File.rm_rf!(Path.join(target, "_build/test/lib/#{dep}"))

    mix_checks = [
      ["compile", "--warnings-as-errors"],
      ["format", "--check-formatted"],
      ["assets.build"],
      ["test"]
    ]

    for args <- mix_checks do
      {out, status} = CourseRunner.cmd_mix(args, cd: target, env: env, stderr_to_stdout: true)
      assert status == 0, "mix #{Enum.join(args, " ")} failed:\n#{String.slice(out, -3000, 3000)}"
    end

    for args <- [["test"], ["run", "check"]] do
      {out, status} = System.cmd("npm", args, cd: target, env: env, stderr_to_stdout: true)
      assert status == 0, "npm #{Enum.join(args, " ")} failed:\n#{String.slice(out, -3000, 3000)}"
      assert args != ["test"] or out =~ ~r/Tests\s+\d+ passed/, "npm test ran no app tests"
    end
  end
end
