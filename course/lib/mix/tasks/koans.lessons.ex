defmodule Mix.Tasks.Koans.Lessons do
  @shortdoc "Write lessons/index.html from the chapter lessons and pictures"
  @moduledoc """
  Writes `lessons/index.html`, one section per chapter with its lesson text and picture.

      mix koans.lessons [--root DIR]
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [root: :string])
    root = Keyword.get(opts, :root, File.cwd!())
    path = Path.join(root, "lessons/index.html")

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Koans.Lessons.build(root))
    Mix.shell().info("wrote #{Path.relative_to(path, root)}")
  end
end
