defmodule Koans.Ts.SourceCheck.KoanFile do
  @moduledoc false

  alias Koans.Ts.Lexer

  @call ~r/(?<![\w$.])test\s*(?:\.\s*[\w$]+\s*)*\(/
  @koan_line ~r/\Atest\("((?:[^"\\]|\\.)*)",/
  @metacharacters ~c"()[]{}*+?|^$\\"
  @shape "test( must be top-level with a one-line double-quoted meditation"

  def errors(%{koan: false}), do: []

  def errors(source) do
    calls = calls(source)
    lines = Enum.count(source.lines, &String.starts_with?(&1, ~s|test("|))

    meditations =
      for call <- calls,
          call.depth == 0,
          [_, meditation] <- [Regex.run(@koan_line, Enum.at(source.lines, call.line - 1))],
          do: {call.line, meditation}

    shape_errors(calls, meditations) ++
      count_errors(lines, length(calls)) ++
      Enum.flat_map(meditations, &metacharacter_errors/1) ++
      duplicate_errors(meditations)
  end

  def calls(source) do
    {calls, _} =
      @call
      |> Regex.scan(source.mask, return: :index)
      |> Enum.map_reduce({0, 0}, fn [{at, len}], {from, depth} ->
        depth = depth + depth_change(binary_part(source.mask, from, at - from))
        open = at + len - 1

        call = %{
          line: Lexer.line_of(source.text, at),
          open: open,
          close: close(source.mask, open),
          depth: depth
        }

        {call, {at, depth}}
      end)

    calls
  end

  defp depth_change(code) do
    Enum.reduce(:binary.bin_to_list(code), 0, fn
      c, d when c in ~c"([{" -> d + 1
      c, d when c in ~c")]}" -> d - 1
      _, d -> d
    end)
  end

  defp close(mask, open) do
    mask
    |> binary_part(open, byte_size(mask) - open)
    |> :binary.bin_to_list()
    |> Enum.reduce_while({0, open}, fn c, {depth, at} ->
      depth = depth + depth_change(<<c>>)
      if depth == 0, do: {:halt, {0, at}}, else: {:cont, {depth, at + 1}}
    end)
    |> elem(1)
  end

  defp shape_errors(calls, meditations) do
    good = MapSet.new(meditations, &elem(&1, 0))
    for call <- calls, call.line not in good, do: {call.line, @shape}
  end

  defp count_errors(same, same), do: []

  defp count_errors(lines, calls),
    do: [{1, ~s|file has #{lines} lines starting test(" but registers #{calls} koans|}]

  defp metacharacter_errors({line, meditation}) do
    found =
      for c <- meditation |> String.to_charlist() |> Enum.uniq(), c in @metacharacters, do: <<c>>

    if found == [],
      do: [],
      else: [{line, "meditation has regex metacharacters: #{Enum.join(found, " ")}"}]
  end

  defp duplicate_errors(meditations) do
    {errors, _} =
      Enum.reduce(meditations, {[], MapSet.new()}, fn {line, meditation}, {errors, seen} ->
        key = cold(meditation)

        if key in seen,
          do: {[{line, "duplicate meditation"} | errors], seen},
          else: {errors, MapSet.put(seen, key)}
      end)

    errors
  end

  defp cold(meditation) do
    meditation
    |> String.replace(~r/ Message shapes?: .*?\.(?=\s|\z)/, "")
    |> String.replace(~r/ 1\. .*\z/, "")
  end
end
