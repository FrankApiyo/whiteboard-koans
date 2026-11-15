defmodule Koans.Ts.Values do
  @moduledoc false

  @regex_after ~c"(,=:[!&|?{;+-*%<>~^"

  def replace(text, blank), do: do_values(text, text, 0, [], blank)

  defp do_values(text, rest, offset, acc, blank) do
    case find_marker(rest) do
      nil ->
        IO.iodata_to_binary(Enum.reverse([rest | acc]))

      start ->
        inner_start = start + 3
        close = matching_paren(rest, inner_start, text, offset, start)
        before = binary_part(rest, 0, start)
        inner = binary_part(rest, inner_start, close - inner_start)
        tail = binary_part(rest, close + 1, byte_size(rest) - close - 1)

        if find_marker(inner),
          do: raise(ArgumentError, "line #{line_of(text, offset + start)}: nested _a(")

        replacement = if blank, do: "__", else: inner
        do_values(text, tail, offset + close + 1, [replacement, before | acc], blank)
    end
  end

  defp find_marker(rest) do
    case Regex.run(~r/(?<![A-Za-z0-9_$.])_a\(/, rest, return: :index) do
      [{start, _}] -> start
      nil -> nil
    end
  end

  defp matching_paren(s, i, text, offset, start) do
    case code(s, i, i, {?(, ?)}, 1) do
      {:ok, index} ->
        index

      {:regex, at} ->
        raise ArgumentError, "line #{line_of(text, offset + at)}: regex literal inside _a("

      :error ->
        raise ArgumentError,
              "line #{line_of(text, offset + start)}: _a( without a closing paren"
    end
  end

  defp line_of(text, offset) do
    text |> binary_part(0, offset) |> String.split("\n") |> length()
  end

  defp code(s, i, _start, _pair, _depth) when i >= byte_size(s), do: :error

  defp code(s, i, start, {open, close} = pair, depth) do
    case :binary.at(s, i) do
      q when q in [?', ?"] -> s |> skip_quoted(i + 1, q) |> continue(s, start, pair, depth)
      ?` -> s |> skip_template(i + 1, start) |> continue(s, start, pair, depth)
      ?/ -> slash(s, i, start, pair, depth)
      ^close when depth == 1 -> {:ok, i}
      ^close -> code(s, i + 1, start, pair, depth - 1)
      ^open -> code(s, i + 1, start, pair, depth + 1)
      _ -> code(s, i + 1, start, pair, depth)
    end
  end

  defp continue({:ok, next}, s, start, pair, depth), do: code(s, next, start, pair, depth)
  defp continue(failure, _s, _start, _pair, _depth), do: failure

  defp slash(s, i, start, pair, depth) do
    case binary_part(s, i, min(2, byte_size(s) - i)) do
      "//" ->
        s |> skip_past(i + 2, "\n") |> continue(s, start, pair, depth)

      "/*" ->
        s |> skip_past(i + 2, "*/") |> continue(s, start, pair, depth)

      _ ->
        if regex_position?(s, i, start), do: {:regex, i}, else: code(s, i + 1, start, pair, depth)
    end
  end

  defp regex_position?(s, i, start) do
    s
    |> binary_part(start, i - start)
    |> String.trim_trailing()
    |> case do
      "" -> true
      before -> :binary.last(before) in @regex_after
    end
  end

  defp skip_past(s, i, terminator) do
    case :binary.match(s, terminator, scope: {i, byte_size(s) - i}) do
      {at, len} -> {:ok, at + len}
      :nomatch -> :error
    end
  end

  defp skip_quoted(s, i, _q) when i >= byte_size(s), do: :error

  defp skip_quoted(s, i, q) do
    case :binary.at(s, i) do
      ?\\ -> skip_quoted(s, i + 2, q)
      ^q -> {:ok, i + 1}
      _ -> skip_quoted(s, i + 1, q)
    end
  end

  defp skip_template(s, i, _start) when i >= byte_size(s), do: :error

  defp skip_template(s, i, start) do
    case binary_part(s, i, min(2, byte_size(s) - i)) do
      "`" <> _ -> {:ok, i + 1}
      "\\" <> _ -> skip_template(s, i + 2, start)
      "${" -> interpolation(s, i + 2, start)
      _ -> skip_template(s, i + 1, start)
    end
  end

  defp interpolation(s, i, start) do
    case code(s, i, start, {?{, ?}}, 1) do
      {:ok, close} -> skip_template(s, close + 1, start)
      failure -> failure
    end
  end
end
