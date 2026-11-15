defmodule Koans.Export.Strip do
  @moduledoc false

  @elixir_marker ~r/\A\s*(?:# [<>]{3} \d\d|<%!-- [<>]{3} \d\d --%>)\s*\z/
  @script_marker ~r/\A\s*(?:\/\/ [<>]{3} \d\d|<!-- [<>]{3} \d\d -->)\s*\z/
  @quiet_import ~r/\A\s*(?:import|alias)\s.*, warn: false\r?\z/
  @quiet_tail ~r/, warn: false(?=\r?\z)/
  @mix_block Path.expand("../../../export/mix_block.exs", __DIR__)
  @external_resource @mix_block

  @course %{
    elixir: {["# >>> course"], ["# <<< course"]},
    script: {["// >>> course", "<!-- >>> course -->"], ["// <<< course", "<!-- <<< course -->"]},
    css: {["/* >>> course */"], ["/* <<< course */"]},
    json: {["// >>> course"], ["// <<< course"]}
  }

  def kind(path) do
    case Path.extname(path) do
      ext when ext in ~w(.ex .exs .heex) -> :elixir
      ext when ext in ~w(.ts .js .mjs .svelte) -> :script
      ".css" -> :css
      ".json" -> :json
      _ -> nil
    end
  end

  def strip(text, kind) do
    {lines, open} =
      text
      |> String.split("\n")
      |> Enum.reduce({[], nil}, &strip_line(&1, &2, kind))

    if open, do: raise(ArgumentError, "course block never closed")
    lines |> Enum.reverse() |> finish(kind) |> Enum.join("\n")
  end

  defp strip_line(line, {out, nil}, kind) do
    {opens, _closes} = @course[kind]
    trimmed = String.trim(line)

    cond do
      trimmed in opens -> {out, []}
      marker?(line, kind) -> {out, nil}
      kind == :elixir and Regex.match?(@quiet_import, line) -> {[unquiet(line) | out], nil}
      true -> {[line | out], nil}
    end
  end

  defp strip_line(line, {out, block}, kind) do
    {_opens, closes} = @course[kind]

    if String.trim(line) in closes,
      do: {replacement(block) ++ out, nil},
      else: {out, [line | block]}
  end

  defp marker?(line, :elixir), do: Regex.match?(@elixir_marker, line)
  defp marker?(line, :script), do: Regex.match?(@script_marker, line)
  defp marker?(_line, _kind), do: false

  defp unquiet(line), do: Regex.replace(@quiet_tail, line, "")

  defp replacement(block) do
    if Enum.any?(block, &String.contains?(&1, "defp elixirc_paths")),
      do:
        @mix_block
        |> File.read!()
        |> String.trim_trailing("\n")
        |> String.split("\n")
        |> Enum.reverse(),
      else: []
  end

  # A course block at the end of a JSON object or array leaves a trailing comma.
  defp finish(lines, :json) do
    lines
    |> Enum.reverse()
    |> Enum.reduce({[], nil}, fn line, {out, next} ->
      trimmed = String.trim(line)

      line =
        if closes?(next) and String.ends_with?(line, ","),
          do: String.slice(line, 0..-2//1),
          else: line

      {[line | out], if(trimmed == "", do: next, else: trimmed)}
    end)
    |> elem(0)
  end

  defp finish(lines, _kind), do: lines

  defp closes?(nil), do: false
  defp closes?(next), do: String.starts_with?(next, ["}", "]"])
end
