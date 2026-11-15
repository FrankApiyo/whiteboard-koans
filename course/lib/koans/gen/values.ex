defmodule Koans.Gen.Values do
  @moduledoc false

  def replace(text, blank), do: do_values(text, text, 0, [], blank)

  defp do_values(text, rest, offset, acc, blank) do
    case find_marker(rest) do
      nil ->
        IO.iodata_to_binary(Enum.reverse([rest | acc]))

      start ->
        open_index = start + 2
        close = matching_paren(rest, open_index + 1, 1, text, offset + open_index)
        before = binary_part(rest, 0, start)
        inner = binary_part(rest, open_index + 1, close - open_index - 1)
        tail = binary_part(rest, close + 1, byte_size(rest) - close - 1)

        if find_marker(inner),
          do: raise(ArgumentError, "line #{line_of(text, offset + start)}: nested _a(")

        replacement = if blank, do: "__", else: inner
        do_values(text, tail, offset + close + 1, [replacement, before | acc], blank)
    end
  end

  defp find_marker(rest) do
    case Regex.run(~r/(?<![A-Za-z0-9_?!@.])_a\(/, rest, return: :index) do
      [{start, _}] -> start
      nil -> nil
    end
  end

  defp matching_paren(s, i, depth, text, origin) do
    case scan(s, i, depth) do
      {:ok, index} -> index
      :error -> raise ArgumentError, "line #{line_of(text, origin)}: _a( without a closing paren"
    end
  end

  defp line_of(text, offset) do
    text |> binary_part(0, offset) |> String.split("\n") |> length()
  end

  defp scan(s, i, depth) when i >= byte_size(s), do: (depth == 0 && {:ok, i}) || :error

  defp scan(s, i, depth) do
    rest = binary_part(s, i, byte_size(s) - i)

    cond do
      String.starts_with?(rest, ~s(""")) ->
        skip_to(s, i + 3, ~s("""), depth)

      String.starts_with?(rest, "'''") ->
        skip_to(s, i + 3, "'''", depth)

      String.starts_with?(rest, "\"") ->
        skip_quoted(s, i + 1, ?", depth)

      String.starts_with?(rest, "'") ->
        skip_quoted(s, i + 1, ?', depth)

      match = Regex.run(~r/\A~[a-zA-Z]("""|'''|[\/|"'(\[{<])/, rest) ->
        skip_sigil(s, i, match, depth)

      char_literal?(s, i) and String.starts_with?(rest, "?\\") ->
        scan(s, i + 3, depth)

      char_literal?(s, i) and String.starts_with?(rest, "?") ->
        scan(s, i + 2, depth)

      String.starts_with?(rest, "#") ->
        skip_comment(s, i, depth)

      String.starts_with?(rest, "(") ->
        scan(s, i + 1, depth + 1)

      String.starts_with?(rest, ")") ->
        if depth == 1, do: {:ok, i}, else: scan(s, i + 1, depth - 1)

      true ->
        scan(s, i + 1, depth)
    end
  end

  defp char_literal?(_s, 0), do: true

  defp char_literal?(s, i) do
    :binary.at(s, i - 1) not in Enum.concat([?a..?z, ?A..?Z, ?0..?9, [?_, ??, ?!]])
  end

  defp skip_comment(s, i, depth) do
    case :binary.match(s, "\n", scope: {i, byte_size(s) - i}) do
      {at, _} -> scan(s, at, depth)
      :nomatch -> :error
    end
  end

  defp skip_to(s, i, terminator, depth) do
    case :binary.match(s, terminator, scope: {i, byte_size(s) - i}) do
      {at, len} -> scan(s, at + len, depth)
      :nomatch -> :error
    end
  end

  defp skip_sigil(s, i, [whole, delimiter], depth) do
    start = i + byte_size(whole)

    case delimiter do
      "(" -> skip_nested(s, start, ?(, ?), depth)
      "[" -> skip_nested(s, start, ?[, ?], depth)
      "{" -> skip_nested(s, start, ?{, ?}, depth)
      "<" -> skip_nested(s, start, ?<, ?>, depth)
      d when d in [~s("""), "'''"] -> skip_to(s, start, d, depth)
      <<c>> -> skip_quoted(s, start, c, depth)
    end
  end

  defp skip_nested(s, i, open, close, depth, level \\ 1)
  defp skip_nested(s, i, _o, _c, _d, _l) when i >= byte_size(s), do: :error

  defp skip_nested(s, i, open, close, depth, level) do
    case :binary.at(s, i) do
      ?\\ -> skip_nested(s, i + 2, open, close, depth, level)
      ^close when level == 1 -> scan(s, i + 1, depth)
      ^close -> skip_nested(s, i + 1, open, close, depth, level - 1)
      ^open -> skip_nested(s, i + 1, open, close, depth, level + 1)
      _ -> skip_nested(s, i + 1, open, close, depth, level)
    end
  end

  defp skip_quoted(s, i, _q, _d) when i >= byte_size(s), do: :error

  defp skip_quoted(s, i, q, depth) do
    case {:binary.at(s, i), s} do
      {?\\, _} ->
        skip_quoted(s, i + 2, q, depth)

      {^q, _} ->
        scan(s, i + 1, depth)

      {?#, _} when q == ?" ->
        if binary_part(s, i, min(2, byte_size(s) - i)) == "\#{" do
          case scan_interpolation(s, i + 2) do
            {:ok, after_brace} -> skip_quoted(s, after_brace, q, depth)
            :error -> :error
          end
        else
          skip_quoted(s, i + 1, q, depth)
        end

      _ ->
        skip_quoted(s, i + 1, q, depth)
    end
  end

  defp scan_interpolation(s, i, level \\ 1)
  defp scan_interpolation(s, i, _level) when i >= byte_size(s), do: :error

  defp scan_interpolation(s, i, level) do
    case :binary.at(s, i) do
      ?} when level == 1 -> {:ok, i + 1}
      ?} -> scan_interpolation(s, i + 1, level - 1)
      ?{ -> scan_interpolation(s, i + 1, level + 1)
      ?" -> skip_inner_string(s, i + 1, level)
      _ -> scan_interpolation(s, i + 1, level)
    end
  end

  defp skip_inner_string(s, i, level) when i >= byte_size(s), do: scan_interpolation(s, i, level)

  defp skip_inner_string(s, i, level) do
    case :binary.at(s, i) do
      ?\\ -> skip_inner_string(s, i + 2, level)
      ?" -> scan_interpolation(s, i + 1, level)
      _ -> skip_inner_string(s, i + 1, level)
    end
  end
end
