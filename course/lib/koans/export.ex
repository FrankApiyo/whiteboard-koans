defmodule Koans.Export do
  @moduledoc false

  alias Koans.Export.Strip

  @commit_message "feat: easel whiteboard app"
  @copied_dirs ~w(lib config priv assets test/support e2e)
  @copied_files ~w(test/test_helper.exs mix.exs mix.lock package.json package-lock.json
                   vitest.config.ts playwright.config.ts LICENSE)
  @copied_globs ["test/easel*"]
  @left_out ~w(lib/easel/hello.ex test/easel/hello_test.exs assets/js/hello.ts
               assets/test/hello.test.ts assets/vitest.config.ts assets/vitest.app.config.ts
               assets/vitest.course.config.ts)
  @left_out_prefixes ~w(priv/static/ priv/svelte/ assets/koans/ assets/koans_support/
                        assets/node_modules/ assets/svelte/_build/)
  @blank ~r/(?<![A-Za-z0-9_$])__(?:blank)?\(/
  @templates [
    {"README.md", "README.md"},
    {"NOTICE", "NOTICE"},
    {"formatter.exs", ".formatter.exs"},
    {"gitignore", ".gitignore"},
    {"ci.yml", ".github/workflows/ci.yml"},
    {"vitest.config.ts", "assets/vitest.config.ts"}
  ]
  @template_dir Path.expand("../../export", __DIR__)

  def run(root, target, opts \\ []) do
    target = Path.expand(target)

    with :ok <- refuse_blanks(root),
         :ok <- refuse_existing(target) do
      build_then_move(root, target, opts)
    end
  end

  def strip(text, path), do: Strip.strip(text, Strip.kind(path))

  defp build_then_move(root, target, opts) do
    staging = target <> ".partial-#{System.unique_integer([:positive])}"

    try do
      files = app_files(root)
      Enum.each(files, &copy_file(root, staging, &1))
      write_templates(staging)

      with :ok <- commit(staging, target, opts),
           :ok <- File.rename(staging, target) |> rename_result(target) do
        {:ok, length(files)}
      end
    rescue
      error -> {:error, "export failed: " <> Exception.message(error)}
    after
      File.rm_rf(staging)
    end
  end

  defp rename_result(:ok, _target), do: :ok
  defp rename_result({:error, reason}, target), do: {:error, "cannot create #{target}: #{reason}"}

  defp refuse_blanks(root) do
    found =
      for rel <- app_files(root),
          text = File.read!(Path.join(root, rel)),
          String.valid?(text),
          {line, number} <- text |> String.split("\n") |> Enum.with_index(1),
          Regex.match?(@blank, line),
          do: "  #{rel}:#{number}  #{String.trim(line)}"

    case found do
      [] ->
        :ok

      blanks ->
        {:error,
         "#{length(blanks)} blank(s) left; fill them first. First three:\n" <>
           Enum.join(Enum.take(blanks, 3), "\n")}
    end
  end

  defp refuse_existing(target) do
    if File.exists?(target), do: {:error, "#{target} already exists"}, else: :ok
  end

  defp app_files(root) do
    dirs =
      for dir <- @copied_dirs,
          do: Path.wildcard(Path.join([root, dir, "**", "*"]), match_dot: true)

    globs =
      for glob <- @copied_globs,
          do: root |> Path.join(glob) |> Path.wildcard() |> Enum.flat_map(&expand/1)

    files = for file <- @copied_files, do: Path.join(root, file)

    (dirs ++ globs ++ files)
    |> List.flatten()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, root))
    |> Enum.reject(&left_out?/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp expand(path) do
    if File.dir?(path), do: Path.wildcard(Path.join(path, "**/*"), match_dot: true), else: [path]
  end

  defp left_out?(rel) do
    rel in @left_out or Path.basename(rel) == ".DS_Store" or
      Enum.any?(@left_out_prefixes, &String.starts_with?(rel, &1))
  end

  defp copy_file(root, target, rel) do
    source = Path.join(root, rel)
    destination = Path.join(target, rel)
    File.mkdir_p!(Path.dirname(destination))

    case {rel, Strip.kind(rel)} do
      {"mix.lock", _} -> File.write!(destination, drop_koans_lock(File.read!(source)))
      {_, nil} -> File.cp!(source, destination)
      {_, kind} -> File.write!(destination, rewrite(rel, kind, File.read!(source)))
    end
  end

  defp rewrite(rel, kind, text) do
    stripped =
      try do
        Strip.strip(text, kind)
      rescue
        error in ArgumentError ->
          reraise ArgumentError, "#{rel}: #{error.message}", __STACKTRACE__
      end

    finish(rel, kind, stripped)
  end

  defp finish(rel, :elixir, text) do
    {format, _opts} = Mix.Tasks.Format.formatter_for_file(rel)
    format.(text)
  end

  defp finish("package.json", _kind, text), do: text |> swap_scripts() |> name_package()
  defp finish("package-lock.json", _kind, text), do: rename_package(text)
  defp finish(_rel, _kind, text), do: text

  defp drop_koans_lock(text) do
    text
    |> String.split("\n")
    |> Enum.reject(&String.starts_with?(String.trim_leading(&1), ~s("koans":)))
    |> Enum.join("\n")
  end

  defp swap_scripts(text) do
    scripts =
      @template_dir
      |> Path.join("package_scripts.json")
      |> File.read!()
      |> String.trim_trailing()
      |> String.replace("\n", "\n  ")

    swapped =
      Regex.replace(~r/"scripts": \{[^{}]*\}/, text, ~s("scripts": ) <> scripts, global: false)

    if swapped == text, do: raise(ArgumentError, "package.json has no scripts object to replace")
    JSON.decode!(swapped)
    swapped
  end

  defp name_package(text) do
    named = String.replace(text, ~r/\A\{\n/, ~s({\n  "name": "easel",\n  "private": true,\n))
    if Map.has_key?(JSON.decode!(text), "name"), do: rename_package(text), else: named
  end

  defp rename_package(text),
    do: Regex.replace(~r/\A\{\n  "name": "[^"]*"/, text, ~s({\n  "name": "easel"))

  defp write_templates(target) do
    for {name, destination} <- @templates do
      path = Path.join(target, destination)
      File.mkdir_p!(Path.dirname(path))
      File.cp!(Path.join(@template_dir, name), path)
    end
  end

  defp commit(staging, target, opts) do
    env = Keyword.get(opts, :git_env, [])

    [["init", "-q", "-b", "main"], ["add", "-A"], ["commit", "-q", "-m", @commit_message]]
    |> Enum.reduce_while(:ok, fn args, :ok ->
      case System.cmd("git", args, cd: staging, env: env, stderr_to_stdout: true) do
        {_, 0} -> {:cont, :ok}
        {out, _} -> {:halt, {:error, "git #{hd(args)} failed for #{target}:\n#{out}"}}
      end
    end)
  end
end
