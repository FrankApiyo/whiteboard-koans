defmodule Koans.Chapters do
  @moduledoc """
  Builds `_verify/` as the course stands after chapter `upto`: answers tagged at
  or below `upto` are filled, the rest are blank. `build(-1)` is the learner's
  tree. Both languages are built, plus `assets/tsconfig.json`. Only files whose
  content changed are written, so Mix and Vite rebuild just the difference
  between two builds.
  """

  alias Koans.Gen
  alias Koans.Gen.Project

  @dir "_verify"

  def build(upto, root \\ File.cwd!()) when upto in -1..99 do
    target = Path.join(root, @dir)
    wanted = Map.new(Project.source_files(root), &{&1.rel, content(&1, upto)})

    for rel <- Project.generated_files(target),
        not Map.has_key?(wanted, rel),
        do: File.rm!(Path.join(target, rel))

    Enum.each(wanted, fn {rel, text} -> write_changed(Path.join(target, rel), text) end)
    Project.write_tsconfig(target)
  end

  defp content(file, upto) do
    chapter = koan_chapter(file)

    cond do
      chapter != nil and chapter <= upto -> Project.content(file, :solutions)
      chapter != nil or upto < 0 or not Project.text?(file) -> Project.content(file, :learner)
      true -> partial(file, upto)
    end
  end

  defp koan_chapter(%{rel: rel}) do
    case {Project.koan_file?(rel), Project.chapter_of(rel)} do
      {true, nn} when nn != nil -> String.to_integer(nn)
      _ -> nil
    end
  end

  defp partial(file, upto) do
    Gen.partial(File.read!(file.path), upto, Project.render_opts(file))
  rescue
    error in ArgumentError ->
      reraise ArgumentError, "source/#{file.rel}: " <> Exception.message(error), __STACKTRACE__
  end

  defp write_changed(path, text) do
    if File.read(path) != {:ok, text} do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, text)
    end
  end
end
