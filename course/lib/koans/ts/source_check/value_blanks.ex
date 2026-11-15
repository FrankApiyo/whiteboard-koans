defmodule Koans.Ts.SourceCheck.ValueBlanks do
  @moduledoc false

  alias Koans.Ts.{Lexer, Values}
  alias Koans.Ts.SourceCheck.KoanFile

  @marker ~r/(?<![A-Za-z0-9_$.])_a\(/
  @destructuring ~r/(?<![\w$.])(?:const|let|var)\s*[\[{][^=]*\z/

  def errors(source) do
    bodies = if source.koan, do: Enum.map(KoanFile.calls(source), &{&1.open, &1.close}), else: []

    found =
      for [{at, _}] <- Regex.scan(@marker, source.text, return: :index),
          rule <- rules(source, at, bodies),
          do: {Lexer.line_of(source.text, at), rule}

    found ++ scanner_errors(source.text)
  end

  defp rules(source, at, bodies) do
    if binary_part(source.mask, at, 3) == "_a(",
      do: code_rules(source, at, bodies),
      else: [hidden_rule(source, at)]
  end

  defp hidden_rule(source, at) do
    case Enum.find(source.spans, fn {_, from, to} -> at >= from and at < to end) do
      {:comment, _, _} -> "value blank in a comment"
      _ -> "value blank in a string"
    end
  end

  defp code_rules(source, at, bodies) do
    line = line_before(source.mask, at)
    whole_line = line <> line_after(source.mask, at)

    for {true, rule} <- [
          {inside?(source.spans, :template, at), "value blank inside a template literal"},
          {not Enum.any?(bodies, fn {from, to} -> at > from and at < to end),
           "value blank outside a test body"},
          {Regex.match?(@destructuring, line), "value blank in a destructuring target"},
          {whole_line =~ ".not." or whole_line =~ "!=",
           "value blank compared with != or under .not"}
        ],
        do: rule
  end

  defp inside?(spans, kind, at),
    do: Enum.any?(spans, fn {k, from, to} -> k == kind and at > from and at < to end)

  defp line_before(mask, at) do
    start =
      case :binary.matches(mask, "\n", scope: {0, at}) do
        [] -> 0
        matches -> elem(List.last(matches), 0) + 1
      end

    binary_part(mask, start, at - start)
  end

  defp line_after(mask, at) do
    case :binary.match(mask, "\n", scope: {at, byte_size(mask) - at}) do
      {stop, _} -> binary_part(mask, at, stop - at)
      :nomatch -> binary_part(mask, at, byte_size(mask) - at)
    end
  end

  defp scanner_errors(text) do
    Values.replace(text, true)
    []
  rescue
    error in ArgumentError ->
      case Regex.run(~r/\Aline (\d+): (.*)\z/s, Exception.message(error)) do
        [_, line, message] -> [{String.to_integer(line), message}]
        nil -> [{1, Exception.message(error)}]
      end
  end
end
