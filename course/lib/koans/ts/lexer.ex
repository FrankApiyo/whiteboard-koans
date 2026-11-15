defmodule Koans.Ts.Lexer do
  @moduledoc false

  @punct_regex_ok ~c"(,=:[!&|?{};+-*%<>~^"
  @keywords ~w(return typeof case do else in of instanceof new delete void throw yield await)

  def scan(text) do
    {mask, spans} = code(text, 0, [], [], [], :regex)
    %{mask: IO.iodata_to_binary(Enum.reverse(mask)), spans: Enum.reverse(spans)}
  end

  def scan_svelte(text) do
    sections = svelte_sections(text)

    {mask, spans} =
      Enum.reduce(sections, {[], []}, fn
        {:script, from, to}, {mask, spans} ->
          %{mask: part, spans: inner} = scan(binary_part(text, from, to - from))
          shifted = Enum.map(inner, fn {kind, a, b} -> {kind, a + from, b + from} end)
          {[part | mask], Enum.reverse(shifted, spans)}

        {:style, from, to}, {mask, spans} ->
          {[blank(binary_part(text, from, to - from)) | mask], spans}

        {:markup, from, to}, {mask, spans} ->
          {[binary_part(text, from, to - from) | mask], spans}
      end)

    %{
      mask: IO.iodata_to_binary(Enum.reverse(mask)),
      spans: Enum.reverse(spans),
      sections: sections
    }
  end

  def svelte_sections(text) do
    tags =
      for {kind, pattern} <- [
            script: ~r/<script\b[^>]*>(.*?)<\/script>/s,
            style: ~r/<style\b[^>]*>(.*?)<\/style>/s
          ],
          [_, {from, len}] <- Regex.scan(pattern, text, return: :index),
          do: {kind, from, from + len}

    {sections, last} =
      tags
      |> Enum.sort_by(&elem(&1, 1))
      |> Enum.reduce({[], 0}, fn {_, from, to} = tag, {acc, at} ->
        {[tag, {:markup, at, from} | acc], to}
      end)

    Enum.reverse([{:markup, last, byte_size(text)} | sections])
  end

  def line_of(text, offset), do: length(:binary.matches(text, "\n", scope: {0, offset})) + 1

  defp blank(binary), do: String.replace(binary, ~r/[^\n]/, " ")

  defp code(s, i, mask, spans, _stack, _prev) when i >= byte_size(s), do: {mask, spans}

  defp code(s, i, mask, spans, stack, prev) do
    c = :binary.at(s, i)

    cond do
      c == ?/ and peek(s, i + 1) == ?/ ->
        to = until(s, i, "\n", 0)
        skip(s, i, to, :comment, mask, spans, stack, prev)

      c == ?/ and peek(s, i + 1) == ?* ->
        to = until(s, i + 2, "*/", 2)
        skip(s, i, to, :comment, mask, spans, stack, prev)

      c == ?/ and prev == :regex ->
        regex(s, i, mask, spans, stack)

      c in [?', ?"] ->
        to = quoted_end(s, i + 1, c)
        code(s, to, [quoted(s, i, to, c) | mask], [{:string, i, to} | spans], stack, :div)

      c == ?` ->
        template(s, i + 1, i, [?` | mask], spans, stack)

      c == ?{ ->
        code(s, i + 1, ["{" | mask], spans, [:brace | stack], :regex)

      c == ?} ->
        close_brace(s, i, mask, spans, stack)

      word?(c) ->
        word = word_at(s, i)
        next = if word in @keywords, do: :regex, else: :div
        code(s, i + byte_size(word), [word | mask], spans, stack, next)

      c in [?), ?]] ->
        code(s, i + 1, [c | mask], spans, stack, :div)

      c in @punct_regex_ok ->
        code(s, i + 1, [c | mask], spans, stack, :regex)

      true ->
        code(s, i + 1, [c | mask], spans, stack, prev)
    end
  end

  defp close_brace(s, i, mask, spans, [{:interp, start} | stack]),
    do: template(s, i + 1, start, ["}" | mask], spans, stack)

  defp close_brace(s, i, mask, spans, stack),
    do: code(s, i + 1, ["}" | mask], spans, Enum.drop(stack, 1), :regex)

  defp skip(s, from, to, kind, mask, spans, stack, prev) do
    part = blank(binary_part(s, from, to - from))
    code(s, to, [part | mask], [{kind, from, to} | spans], stack, prev)
  end

  defp regex(s, i, mask, spans, stack) do
    case regex_end(s, i + 1, false) do
      nil ->
        code(s, i + 1, ["/" | mask], spans, stack, :regex)

      close ->
        to = flags_end(s, close + 1)

        part = [
          "/",
          blank(binary_part(s, i + 1, close - i - 1)),
          binary_part(s, close, to - close)
        ]

        code(s, to, [part | mask], [{:regex, i, to} | spans], stack, :div)
    end
  end

  defp regex_end(s, i, _class) when i >= byte_size(s), do: nil

  defp regex_end(s, i, class) do
    case :binary.at(s, i) do
      ?\n -> nil
      ?\\ -> regex_end(s, i + 2, class)
      ?[ -> regex_end(s, i + 1, true)
      ?] -> regex_end(s, i + 1, false)
      ?/ when not class -> i
      _ -> regex_end(s, i + 1, class)
    end
  end

  defp flags_end(s, i) do
    if i < byte_size(s) and word?(:binary.at(s, i)), do: flags_end(s, i + 1), else: i
  end

  defp template(s, i, start, mask, spans, _stack) when i >= byte_size(s),
    do: {mask, [{:template, start, byte_size(s)} | spans]}

  defp template(s, i, start, mask, spans, stack) do
    case binary_part(s, i, min(2, byte_size(s) - i)) do
      "`" <> _ ->
        code(s, i + 1, ["`" | mask], [{:template, start, i + 1} | spans], stack, :div)

      "\\" <> _ = escape ->
        template(s, i + byte_size(escape), start, [blank(escape) | mask], spans, stack)

      "${" ->
        code(s, i + 2, ["${" | mask], spans, [{:interp, start} | stack], :regex)

      <<c, _::binary>> ->
        template(s, i + 1, start, [if(c == ?\n, do: "\n", else: " ") | mask], spans, stack)
    end
  end

  defp quoted_end(s, i, _q) when i >= byte_size(s), do: byte_size(s)

  defp quoted_end(s, i, q) do
    case :binary.at(s, i) do
      ?\\ -> quoted_end(s, min(i + 2, byte_size(s)), q)
      ?\n -> i
      ^q -> i + 1
      _ -> quoted_end(s, i + 1, q)
    end
  end

  defp quoted(s, from, to, q) do
    closed = to - from >= 2 and :binary.at(s, to - 1) == q
    inner = to - from - if(closed, do: 2, else: 1)
    [q, blank(binary_part(s, from + 1, inner)), if(closed, do: <<q>>, else: "")]
  end

  defp until(s, i, terminator, extra) do
    case :binary.match(s, terminator, scope: {i, byte_size(s) - i}) do
      {at, _} -> at + extra
      :nomatch -> byte_size(s)
    end
  end

  defp peek(s, i), do: if(i < byte_size(s), do: :binary.at(s, i))

  defp word?(c), do: c in ?a..?z or c in ?A..?Z or c in ?0..?9 or c in [?_, ?$]

  defp word_at(s, i) do
    [word] = Regex.run(~r/\A[\w$]+/, binary_part(s, i, byte_size(s) - i))
    word
  end
end
