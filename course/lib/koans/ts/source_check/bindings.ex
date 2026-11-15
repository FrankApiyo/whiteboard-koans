defmodule Koans.Ts.SourceCheck.Bindings do
  @moduledoc false

  alias Koans.Ts.{Lexer, SourceCheck}

  @declaration ~r/^(?:export\s+)?(?:(?:const|let|var)\s+([A-Za-z_$][\w$]*)|(?:async\s+)?function\s*\*?\s*([A-Za-z_$][\w$]*)|class\s+([A-Za-z_$][\w$]*))/
  @destructuring ~r/^(?:export\s+)?(?:const|let|var)\s*[{\[]([^=]*)[}\]]\s*(?::[^=]*)?=/
  @bind_shorthand ~r/\bbind:([\w$]+)(?![\w$]*\s*=)/

  def errors(%{markup: true}, _source), do: []

  def errors(block, source) do
    declared =
      for line <- (block.from + 1)..(block.to - 1)//1,
          text = SourceCheck.line_text(source, line),
          Koans.Markers.indent(text) == block.indent,
          name <- names(String.trim_leading(text)),
          uniq: true,
          do: name

    if declared == [] do
      []
    else
      outside = outside_text(block, %{source | mask: code_mask(source)})

      for name <- declared,
          used?(outside, name),
          do: {block.from, "code blank declares #{name}, used outside it"}
    end
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

  defp used?(text, name) do
    ~r/(?<![\w$.])#{Regex.escape(name)}(?![\w$])/
    |> Regex.scan(text, return: :index)
    |> Enum.any?(fn [{at, len}] -> not key?(text, at, len) end)
  end

  defp key?(text, at, len) do
    after_name = binary_part(text, at + len, byte_size(text) - at - len)
    before = text |> binary_part(0, at) |> String.trim_trailing(" ") |> String.trim_trailing("\t")

    Regex.match?(~r/\A\s*\??\s*:/, after_name) and
      (before == "" or String.ends_with?(before, ["{", ",", ";", "\n"]))
  end

  defp code_mask(%{svelte: false} = source), do: source.mask

  defp code_mask(source) do
    source.sections
    |> Enum.map(fn
      {:markup, from, to} -> markup_expressions(binary_part(source.text, from, to - from))
      {_, from, to} -> binary_part(source.mask, from, to - from)
    end)
    |> IO.iodata_to_binary()
  end

  defp markup_expressions(markup) do
    plain = Regex.replace(~r/<!--.*?-->/s, markup, &String.replace(&1, ~r/[^\n]/, " "))

    shorthands =
      for [_, {at, len}] <- Regex.scan(@bind_shorthand, plain, return: :index), do: {at, at + len}

    {kept, _} =
      plain
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> Enum.map_reduce(0, fn {c, i}, depth ->
        depth = if c == ?{, do: depth + 1, else: depth
        keep = depth > 0 or Enum.any?(shorthands, fn {from, to} -> i >= from and i < to end)
        out = if keep or c == ?\n, do: c, else: ?\s
        {out, if(c == ?} and depth > 0, do: depth - 1, else: depth)}
      end)

    kept |> :binary.list_to_bin() |> Lexer.scan() |> Map.fetch!(:mask)
  end

  defp outside_text(block, source) do
    if depth_before(source, block.from) == 0 do
      mask_lines(source, 1, block.from - 1) <>
        "\n" <> mask_lines(source, block.to + 1, length(source.lines))
    else
      mask_lines(source, block.to + 1, scope_end(block, source))
    end
  end

  defp scope_end(block, source) do
    (block.to + 1)
    |> Stream.iterate(&(&1 + 1))
    |> Stream.take_while(&(&1 <= length(source.lines)))
    |> Enum.take_while(fn line ->
      text = SourceCheck.line_text(source, line)

      String.trim(text) == "" or
        String.length(Koans.Markers.indent(text)) >= String.length(block.indent)
    end)
    |> List.last(block.to)
  end

  defp mask_lines(_source, from, to) when from > to, do: ""

  defp mask_lines(source, from, to) do
    first = elem(source.starts, from - 1)
    last = elem(source.starts, to - 1) + byte_size(SourceCheck.line_text(source, to))
    binary_part(source.mask, first, last - first)
  end

  defp depth_before(source, line) do
    offset = elem(source.starts, line - 1)
    start = SourceCheck.script_start(source, offset)
    code = binary_part(source.mask, start, offset - start)
    length(:binary.matches(code, "{")) - length(:binary.matches(code, "}"))
  end
end
