defmodule Koans.Ts.Values do
  @moduledoc false

  @regex_after ~c"(,=:[!&|?{};+-*%<>~^"
  @regex_keyword ~r/(?<![\w$.])(?:return|typeof|case|do|else|in|of|instanceof|new|delete|void|throw|yield|await)\z/
  @control_paren ~r/(?<![\w$.])(?:if|while|for|with)\s*\(/

  def replace(text, blank) do
    text
    |> segments()
    |> Enum.map(fn
      {:plain, part} -> part
      {:value, _offset, inner} -> if blank, do: "__", else: inner
    end)
    |> IO.iodata_to_binary()
  end

  def answers(text), do: for({:value, offset, inner} <- segments(text), do: {offset, inner})

  defp segments(text), do: do_segments(text, text, 0, [])

  defp do_segments(text, rest, offset, acc) do
    case find_marker(rest) do
      nil ->
        Enum.reverse([{:plain, rest} | acc])

      start ->
        inner_start = start + 3
        close = matching_paren(rest, inner_start, text, offset, start)
        before = binary_part(rest, 0, start)
        inner = binary_part(rest, inner_start, close - inner_start)
        tail = binary_part(rest, close + 1, byte_size(rest) - close - 1)
        value = {:value, offset + inner_start, inner}
        do_segments(text, tail, offset + close + 1, [value, {:plain, before} | acc])
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

      {:nested, at} ->
        raise ArgumentError, "line #{line_of(text, offset + at)}: nested _a("

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
      ?_ -> if marker_at?(s, i), do: {:nested, i}, else: code(s, i + 1, start, pair, depth)
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

  defp marker_at?(s, i),
    do:
      binary_part(s, i, min(3, byte_size(s) - i)) == "_a(" and
        find_marker(binary_part(s, i - 1, 4)) == 1

  defp regex_position?(s, i, start) do
    before = s |> binary_part(start, i - start) |> String.trim_trailing()

    cond do
      before == "" -> true
      :binary.last(before) in @regex_after -> true
      :binary.last(before) == ?) -> Regex.match?(@control_paren, before)
      true -> Regex.match?(@regex_keyword, before)
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
