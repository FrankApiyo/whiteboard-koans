defmodule Koans.Gen.QuietImports do
  @moduledoc false

  alias Koans.Markers

  @bare ~r/\A  (?:import|alias) [A-Z][A-Za-z0-9_.]*(?:\.\{[^}]*\})?(?:,\s*as:\s*[A-Z][A-Za-z0-9_.]*)?\z/
  @heredoc ~r/"""|'''/

  def apply(text) do
    lines = String.split(text, "\n")

    if Enum.any?(lines, &open_region?/1),
      do: lines |> quiet([], :code) |> Enum.join("\n"),
      else: text
  end

  defp open_region?(line), do: match?(%{kind: :open}, Markers.parse_region(line))

  defp quiet([], acc, _state), do: Enum.reverse(acc)

  defp quiet([line | rest], acc, state) do
    case {String.trim(line), state} do
      {"# >>> course", :code} -> quiet(rest, [line | acc], :course)
      {"# <<< course", :course} -> quiet(rest, [line | acc], :code)
      {_, :course} -> quiet(rest, [line | acc], :course)
      _ -> quiet(rest, [add_warn(line, state) | acc], heredoc_state(line, state))
    end
  end

  defp heredoc_state(line, state) do
    if rem(length(Regex.scan(@heredoc, line)), 2) == 1,
      do: if(state == :heredoc, do: :code, else: :heredoc),
      else: state
  end

  defp add_warn(line, :heredoc), do: line

  defp add_warn(line, :code) do
    {body, eol} = split_eol(line)
    if Regex.match?(@bare, body), do: body <> ", warn: false" <> eol, else: line
  end

  defp split_eol(line) do
    if String.ends_with?(line, "\r"),
      do: {String.slice(line, 0..-2//1), "\r"},
      else: {line, ""}
  end
end
