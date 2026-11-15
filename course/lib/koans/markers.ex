defmodule Koans.Markers do
  @moduledoc false

  @hash_open ~r/\A# >>> answer(?: (?<body>.*))?\z/
  @heex_open ~r/\A<%!-- >>> answer(?: (?<body>.+?))? --%>\z/
  @tagged ~r/\A(?<chapter>\d\d): (?<tag>[^"\\|]+?)(?: \| stub: (?<head>.+))?\z/
  @bare_stub ~r/\Astub: (?<head>.+)\z/

  @region_patterns [
    {~r/\A# >>> (\d\d)\z/, :open, false},
    {~r/\A# <<< (\d\d)\z/, :close, false},
    {~r/\A<%!-- >>> (\d\d) --%>\z/, :open, true},
    {~r/\A<%!-- <<< (\d\d) --%>\z/, :close, true}
  ]

  def parse_line(line) do
    trimmed = String.trim(line)

    case trimmed do
      "# <<<" -> %{kind: :close, heex: false}
      "<%!-- <<< --%>" -> %{kind: :close, heex: true}
      _ -> parse_open(trimmed, indent(line))
    end
  end

  def scan(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, number} ->
      case parse_line(line) do
        nil -> []
        marker -> [{number, marker}]
      end
    end)
  end

  def blocks(text) do
    text
    |> scan()
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn
      [{from, %{kind: :open} = open}, {to, %{kind: :close}}] ->
        [Map.merge(open, %{from: from, to: to})]

      _ ->
        []
    end)
  end

  def stray_heex_lines(text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} ->
      (String.contains?(line, "<%!-- >>>") or String.contains?(line, "<%!-- <<<")) and
        parse_line(line) == nil
    end)
    |> Enum.map(&elem(&1, 1))
  end

  def parse_region(line) do
    trimmed = String.trim(line)

    Enum.find_value(@region_patterns, fn {pattern, kind, heex} ->
      case Regex.run(pattern, trimmed) do
        [_, chapter] -> %{kind: kind, chapter: chapter, heex: heex}
        nil -> nil
      end
    end)
  end

  def indent(line),
    do: String.slice(line, 0, String.length(line) - String.length(String.trim_leading(line)))

  def form(marker), do: marker.heex

  def close_text(_close), do: "# <<<"

  def region_text(_region, :open, chapter), do: "# >>> #{chapter}"
  def region_text(_region, :close, chapter), do: "# <<< #{chapter}"

  def default_error(%{default: nil}), do: nil
  def default_error(%{heex: true}), do: "default is not allowed on a HEEx marker"
  def default_error(%{default: ""}), do: "empty default expression"
  def default_error(_marker), do: nil

  def blank_lines(marker, chapter) do
    {open, close} =
      if marker.heex,
        do: {"<%!-- >>> #{chapter} --%>", "<%!-- <<< #{chapter} --%>"},
        else: {"# >>> #{chapter}", "# <<< #{chapter}"}

    [marker.indent <> open, blank_line(marker, chapter), marker.indent <> close]
  end

  def blank_line(marker, chapter) do
    call = blank_call(marker, chapter)
    body = if marker.heex, do: "{#{call}}", else: with_head(marker.head, call)
    marker.indent <> body
  end

  defp with_head(nil, call), do: call
  defp with_head(head, call), do: "#{head}, do: #{call}"

  defp blank_call(%{tag: nil}, _chapter), do: "__()"
  defp blank_call(%{tag: tag, default: nil}, chapter), do: ~s[__("#{chapter}: #{tag}")]

  defp blank_call(%{tag: tag, default: default}, chapter),
    do: ~s[__("#{chapter}: #{tag}", #{default})]

  defp parse_open(trimmed, indent) do
    cond do
      captures = Regex.named_captures(@hash_open, trimmed) ->
        build(captures["body"], false, indent)

      captures = Regex.named_captures(@heex_open, trimmed) ->
        build(captures["body"], true, indent)

      true ->
        nil
    end
  end

  defp build(body, heex, indent) do
    case Regex.split(~r/(?:\A| )\| default: ?/, body, parts: 2) do
      [main] ->
        build_main(main, nil, heex, indent)

      [main, default] ->
        if String.contains?(default, "| stub:"),
          do: :malformed,
          else: build_main(main, String.trim(default), heex, indent)
    end
  end

  defp build_main("", nil, heex, indent), do: open(nil, nil, nil, nil, heex, indent)
  defp build_main("", _default, _heex, _indent), do: :malformed

  defp build_main(body, default, heex, indent) do
    cond do
      c = Regex.named_captures(@tagged, body) ->
        head = if c["head"] == "", do: nil, else: c["head"]

        if heex and head,
          do: :malformed,
          else: open(c["chapter"], c["tag"], head, default, heex, indent)

      c = !heex && Regex.named_captures(@bare_stub, body) ->
        if default, do: :malformed, else: open(nil, nil, c["head"], nil, heex, indent)

      true ->
        :malformed
    end
  end

  defp open(chapter, tag, head, default, heex, indent) do
    %{
      kind: :open,
      chapter: chapter,
      tag: tag,
      head: head,
      default: default,
      heex: heex,
      indent: indent
    }
  end
end
