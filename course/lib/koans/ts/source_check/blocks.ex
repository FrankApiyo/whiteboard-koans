defmodule Koans.Ts.SourceCheck.Blocks do
  @moduledoc false

  alias Koans.Ts.SourceCheck

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
  @declaration ~r/^(?:export\s+)?(?:(?:const|let|var)\s+([A-Za-z_$][\w$]*)|(?:async\s+)?function\s*\*?\s*([A-Za-z_$][\w$]*)|class\s+([A-Za-z_$][\w$]*))/
  @destructuring ~r/^(?:export\s+)?(?:const|let|var)\s*[{\[]([^=]*)[}\]]\s*(?::[^=]*)?=/

  def errors(blocks, source) do
    never_blank = Enum.any?(@never_blank, &Regex.match?(&1, source.path))

    Enum.flat_map(blocks, fn block ->
      List.flatten([
        if(never_blank, do: [{block.from, "marker in a never-a-blank file"}], else: []),
        type_errors(block, source),
        default_errors(block, source),
        binding_errors(block, source)
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
    head = neighbour(source, block.from, -1)
    tail = neighbour(source, block.to, 1)
    body = mask_lines(source, block.from + 1, block.to - 1)

    whole =
      head != nil and tail != nil and String.ends_with?(String.trim(head), "{") and
        String.contains?(head, "(") and String.starts_with?(String.trim(tail), "}") and
        String.length(Koans.Markers.indent(head)) < String.length(block.indent) and
        count(body, "{") == count(body, "}")

    if whole, do: [], else: [{block.from, "default marker does not wrap a whole function body"}]
  end

  defp neighbour(source, line, step) do
    (line + step)
    |> Stream.iterate(&(&1 + step))
    |> Stream.take_while(&(&1 >= 1 and &1 <= length(source.lines)))
    |> Stream.map(&SourceCheck.line_text(source, &1))
    |> Enum.find(&(String.trim(&1) != ""))
  end

  defp mask_lines(_source, from, to) when from > to, do: ""

  defp mask_lines(source, from, to) do
    first = elem(source.starts, from - 1)
    last = elem(source.starts, to - 1) + byte_size(SourceCheck.line_text(source, to))
    binary_part(source.mask, first, last - first)
  end

  defp count(text, char), do: length(:binary.matches(text, char))

  defp binding_errors(%{markup: true}, _source), do: []

  defp binding_errors(block, source) do
    declared =
      for line <- block.from..(block.to - 1)//1,
          line > block.from,
          text = SourceCheck.line_text(source, line),
          Koans.Markers.indent(text) == block.indent,
          name <- names(String.trim_leading(text)),
          do: name

    outside = outside_text(block, source)

    for name <- Enum.uniq(declared),
        Regex.match?(~r/(?<![\w$.])#{Regex.escape(name)}(?![\w$])/, outside),
        do: {block.from, "code blank declares #{name}, used outside it"}
  end

  defp names(text) do
    case Regex.run(@declaration, text) do
      [_ | groups] ->
        Enum.reject(groups, &(&1 == ""))

      nil ->
        case Regex.run(@destructuring, text) do
          [_, inner] -> pattern_names(inner)
          nil -> []
        end
    end
  end

  defp pattern_names(inner) do
    inner
    |> String.split(",")
    |> Enum.flat_map(fn part ->
      part = part |> String.split("=") |> hd() |> String.trim() |> String.trim_leading("...")
      name = part |> String.split(":") |> List.last() |> String.trim()
      if Regex.match?(~r/\A[A-Za-z_$][\w$]*\z/, name), do: [name], else: []
    end)
  end

  defp outside_text(block, source) do
    if depth_before(source, block.from) == 0 do
      mask_lines(source, 1, block.from - 1) <> "\n" <> rest_of_file(block, source)
    else
      rest_of_scope(block, source)
    end
  end

  defp rest_of_file(block, source), do: mask_lines(source, block.to + 1, length(source.lines))

  defp rest_of_scope(block, source) do
    last =
      (block.to + 1)
      |> Stream.iterate(&(&1 + 1))
      |> Stream.take_while(&(&1 <= length(source.lines)))
      |> Enum.take_while(fn line ->
        text = SourceCheck.line_text(source, line)

        String.trim(text) == "" or
          String.length(Koans.Markers.indent(text)) >= String.length(block.indent)
      end)
      |> List.last(block.to)

    mask_lines(source, block.to + 1, last)
  end

  defp depth_before(source, line) do
    offset = elem(source.starts, line - 1)

    start =
      Enum.find_value(source.sections, 0, fn {kind, from, to} ->
        if kind == :script and offset >= from and offset < to, do: from
      end)

    code = binary_part(source.mask, start, offset - start)
    count(code, "{") - count(code, "}")
  end
end
