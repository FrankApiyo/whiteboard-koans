defmodule Koans.Gen.Imports do
  @moduledoc false

  alias Koans.Markers

  @block ["# >>> course", "import Koans, only: [__: 1, __: 2], warn: false", "# <<< course"]

  def after_lines(text, opts) do
    answer_lines = tagged_answer_lines(text)

    if Keyword.get(opts, :imports, true) and answer_lines != [] do
      text |> module_ranges() |> import_blocks(answer_lines, text)
    else
      %{}
    end
  end

  defp tagged_answer_lines(text) do
    for {number, %{kind: :open, chapter: chapter}} when chapter != nil <- Markers.scan(text),
        do: number
  end

  defp module_ranges(text) do
    case Code.string_to_quoted(text, columns: true, token_metadata: true) do
      {:ok, ast} ->
        collect_modules(ast)

      {:error, {location, _message, _token}} ->
        line = if is_list(location), do: Keyword.get(location, :line, 1), else: location

        raise ArgumentError,
              "line #{line}: cannot place the course import in a file that does not parse"
    end
  end

  defp collect_modules(ast) do
    {_, found} =
      Macro.prewalk(ast, [], fn
        {:defmodule, meta, _} = node, acc ->
          last = get_in(meta, [:end, :line])
          {node, if(last, do: [{meta[:line], last} | acc], else: acc)}

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp import_blocks(ranges, answer_lines, text) do
    lines = String.split(text, "\n")

    answer_lines
    |> Enum.map(&innermost(ranges, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Map.new(fn first -> {first, block_at(Enum.at(lines, first - 1), first)} end)
  end

  defp innermost(ranges, line) do
    ranges
    |> Enum.filter(fn {first, last} -> first < line and last > line end)
    |> Enum.max_by(&elem(&1, 0), fn -> nil end)
    |> case do
      nil -> nil
      {first, _} -> first
    end
  end

  defp block_at(defmodule_line, number) do
    unless String.ends_with?(String.trim(defmodule_line), " do"),
      do:
        raise(
          ArgumentError,
          "line #{number}: cannot place the course import after a multi-line defmodule head"
        )

    indent = Markers.indent(defmodule_line) <> "  "
    Enum.map(@block, &(indent <> &1))
  end
end
