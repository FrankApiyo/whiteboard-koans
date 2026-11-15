defmodule Koans.Ts.Markers do
  @moduledoc false

  import Koans.Markers, only: [indent: 1]

  @script_open ~r/\A\/\/ >>> answer(?: (?<body>.*))?\z/
  @markup_open ~r/\A<!-- >>> answer(?: (?<body>.+?))? -->\z/
  @tagged ~r/\A(?<chapter>\d\d): (?<tag>[^"\\|]+?)\z/

  @region_patterns [
    {~r/\A\/\/ >>> (\d\d)\z/, :open, false},
    {~r/\A\/\/ <<< (\d\d)\z/, :close, false},
    {~r/\A<!-- >>> (\d\d) -->\z/, :open, true},
    {~r/\A<!-- <<< (\d\d) -->\z/, :close, true}
  ]

  def parse_line(line) do
    trimmed = String.trim(line)

    case trimmed do
      "// <<<" -> %{kind: :close, markup: false}
      "<!-- <<< -->" -> %{kind: :close, markup: true}
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

  def parse_region(line) do
    trimmed = String.trim(line)

    Enum.find_value(@region_patterns, fn {pattern, kind, markup} ->
      case Regex.run(pattern, trimmed) do
        [_, chapter] -> %{kind: kind, chapter: chapter, markup: markup}
        nil -> nil
      end
    end)
  end

  def form(marker), do: marker.markup

  def close_text(%{markup: true}), do: "<!-- <<< -->"
  def close_text(_close), do: "// <<<"

  def region_text(%{markup: true}, :open, chapter), do: "<!-- >>> #{chapter} -->"
  def region_text(%{markup: true}, :close, chapter), do: "<!-- <<< #{chapter} -->"
  def region_text(_region, :open, chapter), do: "// >>> #{chapter}"
  def region_text(_region, :close, chapter), do: "// <<< #{chapter}"

  def default_error(%{default: nil}), do: nil
  def default_error(%{markup: true}), do: "default is not allowed on a markup marker"
  def default_error(%{default: ""}), do: "empty default expression"
  def default_error(_marker), do: nil

  def blank_lines(marker, chapter) do
    [
      marker.indent <> region_text(marker, :open, chapter),
      blank_line(marker, chapter),
      marker.indent <> region_text(marker, :close, chapter)
    ]
  end

  def blank_line(%{markup: true} = marker, chapter),
    do: marker.indent <> ~s[{__blank("#{chapter}: #{marker.tag}", "")}]

  def blank_line(%{default: nil} = marker, chapter),
    do: marker.indent <> ~s[__blank("#{chapter}: #{marker.tag}");]

  def blank_line(marker, chapter),
    do: marker.indent <> ~s[return __blank("#{chapter}: #{marker.tag}", #{marker.default});]

  defp parse_open(trimmed, indent) do
    cond do
      captures = Regex.named_captures(@script_open, trimmed) ->
        build(captures["body"], false, indent)

      captures = Regex.named_captures(@markup_open, trimmed) ->
        build(captures["body"], true, indent)

      true ->
        nil
    end
  end

  defp build(body, markup, indent) do
    {main, default} =
      case Regex.split(~r/ \| default: ?/, body, parts: 2) do
        [main] -> {main, nil}
        [main, default] -> {main, String.trim(default)}
      end

    tagged = Regex.named_captures(@tagged, main)

    if tagged == nil or (default != nil and String.contains?(default, "| stub:")) do
      :malformed
    else
      %{
        kind: :open,
        chapter: tagged["chapter"],
        tag: tagged["tag"],
        default: default,
        markup: markup,
        indent: indent
      }
    end
  end
end
