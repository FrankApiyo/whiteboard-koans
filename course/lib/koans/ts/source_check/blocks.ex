defmodule Koans.Ts.SourceCheck.Blocks do
  @moduledoc false

  alias Koans.Ts.SourceCheck.{Bindings, FunctionBody}

  @never_blank [
    ~r{\.d\.ts\z},
    ~r{(^|/)assets/koans_support/},
    ~r{(^|/)assets/js/(types|live)\.ts\z},
    ~r{(^|/)assets/js/app\.js\z},
    ~r{(^|/)assets/test/support/(fake_[^/]*|setup)\.ts\z},
    ~r{(^|/)(vite|vitest)(\.[\w.]+)?\.config\.(ts|js|mjs)\z},
    ~r{(^|/)svelte\.config\.js\z}
  ]
  @type_line ~r/^\s*(?:export\s+)?(?:declare\s+)?(?:type\s+[A-Za-z_$][\w$]*\b[^=]*=|interface\s+[A-Za-z_$])/

  def errors(blocks, source) do
    never_blank = Enum.any?(@never_blank, &Regex.match?(&1, source.path))

    Enum.flat_map(blocks, fn block ->
      List.flatten([
        if(never_blank, do: [{block.from, "marker in a never-a-blank file"}], else: []),
        type_errors(block, source),
        default_errors(block, source),
        Bindings.errors(block, source)
      ])
    end)
  end

  defp inside(block, source), do: Enum.slice(source.lines, block.from, block.to - block.from - 1)

  defp type_errors(block, source) do
    if Enum.any?(inside(block, source), &Regex.match?(@type_line, &1)),
      do: [{block.from, "marker around a type or interface declaration"}],
      else: []
  end

  defp default_errors(%{default: nil}, _source), do: []
  defp default_errors(%{markup: true}, _source), do: []

  defp default_errors(block, source) do
    if FunctionBody.whole?(block, source),
      do: [],
      else: [{block.from, "default marker does not wrap a whole function body"}]
  end
end
