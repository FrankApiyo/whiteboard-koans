defmodule Koans.Gen.Reblank do
  @moduledoc false

  alias Koans.Markers

  def run(learner_text, source_text, chapter, opts \\ []) do
    syntax = Koans.Gen.syntax(opts)
    fresh_opts = Keyword.merge(opts, chapter: chapter, imports: false)
    fresh_text = Koans.Gen.learner(source_text, fresh_opts)
    fresh = regions(fresh_text, chapter, syntax)
    lines = String.split(learner_text, "\n")
    existing = regions(learner_text, chapter, syntax)

    cond do
      existing == [] and fresh == [] ->
        learner_text

      length(existing) != length(fresh) ->
        raise ArgumentError,
              "chapter #{chapter}: the file has #{length(existing)} marked regions, " <>
                "the source has #{length(fresh)}" <>
                missing_region(existing, lines, fresh, String.split(fresh_text, "\n"), syntax)

      true ->
        replacements =
          existing
          |> Enum.zip(fresh)
          |> Map.new(fn {old, new} -> {old.open, {old.close, adapt(new, old)}} end)

        lines
        |> Enum.with_index(1)
        |> rebuild(replacements, [])
        |> Enum.join("\n")
        |> then(&if syntax == Markers, do: Koans.Gen.QuietImports.apply(&1), else: &1)
    end
  end

  def regions(text, chapter, syntax \\ Markers) do
    {done, open} =
      text
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.reduce({[], nil}, &region_line(&1, &2, chapter, syntax))

    if open, do: never_closed(open, chapter, syntax)
    Enum.reverse(done)
  end

  defp never_closed(open, chapter, syntax) do
    raise ArgumentError,
          "line #{open.open}: #{syntax.region_text(open.region, :open, chapter)} never closed"
  end

  defp region_line({line, number}, {done, open}, chapter, syntax) do
    case syntax.parse_region(line) do
      %{kind: :open, chapter: ^chapter} = region ->
        if open, do: never_closed(open, chapter, syntax)
        {done, %{open: number, open_text: line, region: region, lines: []}}

      %{kind: :close, chapter: ^chapter} = region ->
        if open == nil do
          raise ArgumentError,
                "line #{number}: #{syntax.region_text(region, :close, chapter)} without a " <>
                  syntax.region_text(region, :open, chapter)
        end

        {[%{open | lines: Enum.reverse(open.lines)} |> Map.put(:close, number) | done], nil}

      _ ->
        {done, open && %{open | lines: [line | open.lines]}}
    end
  end

  defp missing_region(existing, lines, fresh, fresh_lines, syntax) do
    mine = outside_lines(lines, syntax)
    theirs = outside_lines(fresh_lines, syntax)

    found =
      Enum.reduce_while(fresh, {existing, 0}, fn region, {left, after_line} ->
        anchor = anchor(theirs, region.open)

        case left do
          [first | rest] ->
            if anchor(mine, first.open) == anchor,
              do: {:cont, {rest, first.close}},
              else: {:halt, {:missing, region, anchor, after_line}}

          [] ->
            {:halt, {:missing, region, anchor, after_line}}
        end
      end)

    case found do
      {:missing, region, anchor, after_line} ->
        place = Enum.find(mine, fn {number, text} -> number > after_line and text == anchor end)
        describe_missing(region, place)

      _all_matched ->
        ""
    end
  end

  defp describe_missing(region, place) do
    name =
      case Regex.run(~r/__(?:blank)?\("([^"]*)"/, Enum.join(region.lines, "\n")) do
        [_, tag] -> ~s(. The markers of "#{tag}" are missing)
        nil -> ". A region's markers are missing"
      end

    case place do
      {number, _text} -> "#{name}; they belong after line #{number}"
      nil -> name
    end
  end

  defp outside_lines(lines, syntax) do
    {outside, _depth} =
      lines
      |> Enum.with_index(1)
      |> Enum.reduce({[], 0}, fn {line, number}, {acc, depth} ->
        case syntax.parse_region(line) do
          %{kind: :open} -> {acc, depth + 1}
          %{kind: :close} -> {acc, max(depth - 1, 0)}
          _ -> {keep_outside(acc, line, number, depth), depth}
        end
      end)

    Enum.reverse(outside)
  end

  defp keep_outside(acc, line, number, 0) do
    case String.trim(line) do
      "" -> acc
      text -> [{number, String.replace_suffix(text, ", warn: false", "")} | acc]
    end
  end

  defp keep_outside(acc, _line, _number, _depth), do: acc

  defp anchor(outside, open) do
    outside |> Enum.take_while(&(elem(&1, 0) < open)) |> List.last() |> then(&(&1 && elem(&1, 1)))
  end

  defp adapt(fresh, old) do
    fresh_indent = Markers.indent(fresh.open_text)
    indent = Markers.indent(old.open_text)
    eol = if String.ends_with?(old.open_text, "\r"), do: "\r", else: ""

    Enum.map(fresh.lines, fn line ->
      line =
        if String.starts_with?(line, fresh_indent),
          do: indent <> String.replace_prefix(line, fresh_indent, ""),
          else: line

      line <> eol
    end)
  end

  defp rebuild([], _replacements, acc), do: Enum.reverse(acc)

  defp rebuild([{line, number} | rest], replacements, acc) do
    case replacements do
      %{^number => {close, fresh}} ->
        tail = Enum.drop_while(rest, fn {_, n} -> n < close end)
        rebuild(tail, replacements, Enum.reverse(fresh, [line | acc]))

      _ ->
        rebuild(rest, replacements, [line | acc])
    end
  end
end
