defmodule Koans.Gen.Reset do
  @moduledoc false

  alias Koans.Gen
  alias Koans.Gen.{Backup, Project}

  def chapter(root, chapter) do
    with {:ok, plan} <- plan(root, chapter), do: {:ok, apply_plan(root, plan)}
  end

  def no_chapter(root, chapter) do
    case root |> Project.koan_chapters() |> Enum.sort() do
      [] ->
        "no chapter #{chapter}"

      chapters ->
        "no chapter #{chapter}: chapters are two digits, #{hd(chapters)} to #{List.last(chapters)}"
    end
  end

  def cold(root, chapter) do
    with :ok <- ensure_source(root),
         {:ok, koans} <- koan_files(root, chapter) do
      tests = Enum.filter(koans, &Project.koan_test?(&1.rel))

      cold =
        for koan <- tests,
            text = File.read!(koan.path),
            opts = Project.render_opts(koan),
            cold_text = Gen.cold(text, opts),
            cold_text != Gen.learner(text, opts),
            do: {koan.rel, cold_text}

      if cold == [] do
        {:ok, :nothing_to_strip, Enum.map(tests, & &1.rel)}
      else
        with {:ok, plan} <- plan(root, chapter) do
          apply_plan(root, Enum.reduce(cold, plan, &List.keystore(&2, elem(&1, 0), 0, &1)))
          {:ok, :cold, Enum.map(cold, &elem(&1, 0))}
        end
      end
    end
  end

  defp plan(root, chapter) do
    with :ok <- ensure_source(root),
         {:ok, koans} <- koan_files(root, chapter) do
      plan =
        root
        |> Project.source_files()
        |> Enum.filter(&resettable?(&1, chapter, koans))
        |> Enum.map(&{&1.rel, reset_text(root, &1, chapter)})

      {:ok, plan}
    end
  rescue
    error in ArgumentError -> {:error, Exception.message(error)}
  end

  defp apply_plan(root, plan) do
    changed = for {rel, text} <- plan, changed?(root, rel, text), do: {rel, text}
    :ok = Backup.save(root, Enum.map(changed, &elem(&1, 0)), :reset)

    for {rel, text} <- changed do
      target = Path.join(root, rel)
      File.mkdir_p!(Path.dirname(target))
      File.write!(target, text)
      rel
    end
  end

  defp changed?(root, rel, text), do: File.read(Path.join(root, rel)) != {:ok, text}

  defp ensure_source(root),
    do: if(File.dir?(Path.join(root, "source")), do: :ok, else: {:error, :no_source})

  defp koan_files(root, chapter) do
    root
    |> Project.source_files()
    |> Enum.filter(&(Project.koan_file?(&1.rel) and Project.chapter_of(&1.rel) == chapter))
    |> case do
      [] -> {:error, :no_chapter}
      files -> {:ok, files}
    end
  end

  defp resettable?(file, chapter, koans) do
    file in koans or (not Project.koan_file?(file.rel) and has_chapter?(file, chapter))
  end

  defp has_chapter?(%{path: path} = file, chapter) do
    syntax = file |> Project.render_opts() |> Gen.syntax()

    Project.text?(file) and
      Enum.any?(syntax.scan(File.read!(path)), fn
        {_, %{kind: :open, chapter: ^chapter}} -> true
        _ -> false
      end)
  end

  defp reset_text(root, file, chapter) do
    source = File.read!(file.path)
    target = Path.join(root, file.rel)

    if Project.koan_file?(file.rel) or not File.exists?(target) do
      Project.learner_text(file, source)
    else
      reblank(file, File.read!(target), source, chapter)
    end
  end

  defp reblank(file, learner, source, chapter) do
    Gen.reblank(learner, source, chapter, Project.render_opts(file))
  rescue
    error in ArgumentError ->
      message = "#{file.rel}: #{Exception.message(error)}\n#{marker_hint(file.rel, chapter)}"
      reraise ArgumentError, message, __STACKTRACE__
  end

  defp marker_hint(rel, chapter) do
    "Each chapter #{chapter} blank sits between #{marker_lines(Path.extname(rel), chapter)}. " <>
      "Put back the missing line, keeping your code between the two, " <>
      "then run mix koans.reset #{chapter} again. Nothing was changed."
  end

  defp marker_lines(".svelte", chapter) do
    "#{marker_lines(".ts", chapter)} (in markup, a line <!-- >>> #{chapter} --> " <>
      "and a line <!-- <<< #{chapter} -->)"
  end

  defp marker_lines(ext, chapter) when ext in [".ts", ".js"],
    do: "a line // >>> #{chapter} and a line // <<< #{chapter}"

  defp marker_lines(_ext, chapter), do: "a line # >>> #{chapter} and a line # <<< #{chapter}"
end
