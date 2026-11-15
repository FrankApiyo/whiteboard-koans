defmodule Koans.Gen.Project do
  @moduledoc false

  alias Koans.{Gen, SourceCheck, Ts}

  @generated_dirs [
    "lib",
    "test/support",
    "test/koans",
    "assets/js",
    "assets/svelte",
    "assets/test",
    "assets/koans"
  ]
  @elixir_extensions ~w(.ex .exs .heex)
  @text_extensions @elixir_extensions ++ ~w(.ts .js .svelte)
  @koan_dirs ["test/koans/", "assets/koans/"]

  def write_all(root, only \\ nil) do
    with :ok <- ensure_source(root) do
      files = source_files(root)

      case check(root, files) do
        [] ->
          written = write_sides(root, selected(files, only), [:learner, :solutions])
          write_tsconfig(side_root(root, :solutions))
          {:ok, length(written)}

        errors ->
          {:error, errors}
      end
    end
  end

  def write_learner(root) do
    with :ok <- ensure_source(root) do
      changed =
        for file <- source_files(root),
            content = content(file, :learner),
            File.read(Path.join(root, file.rel)) != {:ok, content},
            do: {file.rel, content}

      rels = Enum.map(changed, &elem(&1, 0))
      :ok = Koans.Gen.Backup.save(root, rels)
      Enum.each(changed, fn {rel, content} -> write_file!(Path.join(root, rel), content) end)
      {:ok, rels}
    end
  end

  def koan_chapters(root) do
    for file <- source_files(root),
        koan_file?(file.rel),
        chapter = chapter_of(file.rel),
        uniq: true,
        do: chapter
  end

  def koan_file?(rel), do: Enum.any?(@koan_dirs, &String.starts_with?(rel, &1))

  def koan_test?(rel),
    do: koan_file?(rel) and Regex.match?(~r/(_test\.exs|\.test\.ts)\z/, rel)

  def chapter_of(rel) do
    case Regex.run(~r/\A(\d\d)_/, Path.basename(rel)) do
      [_, chapter] -> chapter
      nil -> nil
    end
  end

  def source_files(root) do
    source = Path.join(root, "source")
    for rel <- generated_files(source), do: %{path: Path.join(source, rel), rel: rel}
  end

  def generated_files(base) do
    for dir <- @generated_dirs,
        path <- Path.wildcard(Path.join([base, dir, "**", "*"]), match_dot: true),
        File.regular?(path),
        do: Path.relative_to(path, base)
  end

  def text?(%{rel: rel}), do: Path.extname(rel) in @text_extensions

  def check(root, files \\ nil) do
    files = files || source_files(root)
    chapters = koan_chapters(root)
    texts = for file <- files, text?(file), into: %{}, do: {file.rel, File.read!(file.path)}
    ts_opts = [chapters: chapters] ++ Ts.SourceCheck.context(Enum.to_list(texts))

    files
    |> Enum.filter(&Map.has_key?(texts, &1.rel))
    |> Enum.flat_map(fn file ->
      path = Path.join("source", file.rel)
      text = texts[file.rel]

      result =
        if Path.extname(file.rel) in @elixir_extensions,
          do: SourceCheck.check(text, path, chapters: chapters),
          else: Ts.SourceCheck.check(text, path, ts_opts)

      case result do
        :ok -> []
        {:error, errors} -> errors
      end
    end)
  end

  def learner_text(file, text) do
    Gen.learner(text, render_opts(file))
  rescue
    error in ArgumentError ->
      reraise ArgumentError, "source/#{file.rel}: " <> Exception.message(error), __STACKTRACE__
  end

  def render_opts(%{rel: rel}) do
    ext = Path.extname(rel)
    [chapter: chapter_of(rel), imports: ext == ".ex", ext: ext]
  end

  def tsconfig do
    """
    {
      "extends": "../../assets/tsconfig.json",
      "compilerOptions": {
        "paths": { "@koans/*": ["../../assets/koans_support/*"] }
      },
      "include": [
        "js/**/*.ts",
        "svelte/**/*",
        "koans/**/*",
        "test/**/*",
        "../../assets/koans_support/**/*"
      ]
    }
    """
  end

  def write_tsconfig(tree) do
    path = Path.join([tree, "assets", "tsconfig.json"])
    if File.read(path) != {:ok, tsconfig()}, do: write_file!(path, tsconfig())
    :ok
  end

  defp ensure_source(root),
    do: if(File.dir?(Path.join(root, "source")), do: :ok, else: {:error, :no_source})

  defp selected(files, nil), do: files

  defp selected(files, only) do
    Enum.filter(files, fn file ->
      chapter = koan_file?(file.rel) && chapter_of(file.rel)
      chapter in [false, nil] or chapter in only
    end)
  end

  defp write_sides(root, files, sides) do
    for file <- files, side <- sides, do: {file.rel, write_one(root, file, side)}
  end

  defp write_one(root, file, side) do
    target = Path.join(side_root(root, side), file.rel)
    content = content(file, side)
    changed = File.read(target) != {:ok, content}
    write_file!(target, content)
    changed
  end

  defp write_file!(target, content) do
    File.mkdir_p!(Path.dirname(target))
    File.write!(target, content)
  end

  def content(file, side) do
    if text?(file),
      do: render(file, side),
      else: File.read!(file.path)
  end

  def side_root(root, :learner), do: root
  def side_root(root, :solutions), do: Path.join(root, "solutions")

  defp render(file, :learner), do: learner_text(file, File.read!(file.path))
  defp render(file, :solutions), do: Gen.solutions(File.read!(file.path), render_opts(file))
end
