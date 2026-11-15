defmodule Koans.Ts.SourceCheck do
  @moduledoc false

  alias Koans.Ts.{Lexer, Markers}
  alias Koans.Ts.SourceCheck.{Blocks, KoanFile, ValueBlanks}

  @line_length 98
  @ts_extensions ~w(.ts .js .svelte)
  @elixir_extensions ~w(.ex .exs .heex)
  @exercises ~r/exercises:\s*(?:"([^"]*)"|\[([^\]]*)\])/
  @koan_file ~r{(^|/)assets/koans/(?<chapter>\d\d)_[^/]*\.test\.ts\z}
  @ts_script ~r/\blang\s*=\s*["']ts["']/

  def check(text, path, opts \\ []) do
    source = source(text, path)
    markers = Markers.scan(text)
    {blocks, pairing} = pair(markers)

    errors =
      [
        Enum.flat_map(markers, &marker_errors(&1, source, opts)),
        pairing,
        stray_errors(source),
        svelte_errors(source),
        if(pairing == [], do: Blocks.errors(blocks, source), else: []),
        ValueBlanks.errors(source),
        KoanFile.errors(source)
      ]
      |> Enum.concat()
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn {line, rule} -> "#{path}:#{line}: #{rule}" end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  def context(files) do
    tags =
      for {rel, text} <- files,
          {_line, %{kind: :open, chapter: chapter, tag: tag}} <- scan_any(rel, text),
          tag != nil,
          do: "#{chapter}: #{tag}"

    exercised =
      for {rel, text} <- files,
          captures = Regex.named_captures(@koan_file, rel),
          tag <- exercises(text),
          do: {captures["chapter"], tag}

    [tag_counts: Enum.frequencies(tags), exercised: exercised]
  end

  def koan_file?(path), do: Regex.match?(@koan_file, path)

  def exercises(text) do
    for [_ | groups] <- Regex.scan(@exercises, text),
        group <- groups,
        group != "",
        tag <- tags_in(group),
        do: tag
  end

  defp tags_in(group) do
    case Regex.scan(~r/"([^"]*)"/, group) do
      [] -> [group]
      quoted -> Enum.map(quoted, fn [_, tag] -> tag end)
    end
  end

  defp scan_any(rel, text) do
    cond do
      Path.extname(rel) in @ts_extensions -> Markers.scan(text)
      Path.extname(rel) in @elixir_extensions -> Koans.Markers.scan(text)
      true -> []
    end
  end

  defp source(text, path) do
    svelte = Path.extname(path) == ".svelte"
    lexed = if svelte, do: Lexer.scan_svelte(text), else: Lexer.scan(text)
    lines = String.split(text, "\n")

    %{
      text: text,
      path: path,
      lines: lines,
      starts: line_starts(lines),
      mask: lexed.mask,
      spans: lexed.spans,
      sections: Map.get(lexed, :sections, [{:script, 0, byte_size(text)}]),
      svelte: svelte,
      koan: koan_file?(path)
    }
  end

  defp line_starts(lines) do
    lines
    |> Enum.scan(0, fn line, at -> at + byte_size(line) + 1 end)
    |> then(&[0 | Enum.drop(&1, -1)])
    |> List.to_tuple()
  end

  def section_of(source, line) do
    offset =
      elem(source.starts, line - 1) + byte_size(Koans.Markers.indent(line_text(source, line)))

    Enum.find_value(source.sections, :markup, fn {kind, from, to} ->
      if offset >= from and offset < to, do: kind
    end)
  end

  def line_text(source, line), do: Enum.at(source.lines, line - 1, "")

  def script_start(source, offset) do
    Enum.find_value(source.sections, 0, fn {kind, from, to} ->
      if kind == :script and offset >= from and offset < to, do: from
    end)
  end

  defp pair(markers) do
    {blocks, errors, open} =
      Enum.reduce(markers, {[], [], nil}, fn
        {_, :malformed}, acc ->
          acc

        {n, %{kind: :open} = marker}, {blocks, errs, nil} ->
          {blocks, errs, {n, marker}}

        {n, %{kind: :open} = marker}, {blocks, errs, _} ->
          {blocks, [{n, "nested answer marker"} | errs], {n, marker}}

        {n, %{kind: :close} = close}, {blocks, errs, {from, open}} ->
          if close.markup == open.markup,
            do: {[Map.merge(open, %{from: from, to: n}) | blocks], errs, nil},
            else: {blocks, [{n, "closing marker does not match its opening"} | errs], nil}

        {n, %{kind: :close}}, {blocks, errs, nil} ->
          {blocks, [{n, "unmatched answer marker"} | errs], nil}
      end)

    errors = if open, do: [{elem(open, 0), "unmatched answer marker"} | errors], else: errors
    {Enum.reverse(blocks), errors}
  end

  defp marker_errors({line, :malformed}, source, _opts) do
    if String.contains?(line_text(source, line), "| stub:"),
      do: [{line, "TypeScript has no stub marker"}],
      else: [{line, "malformed answer marker"}]
  end

  defp marker_errors({line, %{kind: :open} = marker}, source, opts) do
    tag = "#{marker.chapter}: #{marker.tag}"

    placement_errors(line, marker, source) ++
      default_errors(line, marker) ++
      duplicate_errors(line, tag, source, opts) ++
      chapter_errors(line, marker.chapter, opts[:chapters]) ++
      exercise_errors(line, marker, tag, opts[:exercised]) ++
      width_errors(line, marker)
  end

  defp marker_errors({line, marker}, source, _opts), do: placement_errors(line, marker, source)

  defp placement_errors(line, marker, source) do
    case {marker.markup, section_of(source, line), source.svelte} do
      {false, :script, _} -> []
      {false, _, _} -> [{line, "// marker outside <script>"}]
      {true, :markup, _} -> []
      {true, :style, _} -> [{line, "markup marker inside <style>"}]
      {true, :script, true} -> [{line, "markup marker inside <script>"}]
      {true, :script, false} -> [{line, "markup marker in a script file"}]
    end
  end

  defp default_errors(line, marker) do
    case Markers.default_error(marker) do
      nil -> []
      message -> [{line, message}]
    end
  end

  defp duplicate_errors(line, tag, source, opts) do
    counts = opts[:tag_counts] || local_tag_counts(source.text)
    if Map.get(counts, tag, 0) > 1, do: [{line, "duplicate answer tag #{tag}"}], else: []
  end

  defp local_tag_counts(text) do
    text
    |> Markers.scan()
    |> Enum.flat_map(fn
      {_, %{kind: :open} = m} -> ["#{m.chapter}: #{m.tag}"]
      _ -> []
    end)
    |> Enum.frequencies()
  end

  defp chapter_errors(_line, _chapter, nil), do: []

  defp chapter_errors(line, chapter, chapters) do
    if chapter in chapters,
      do: [],
      else: [{line, "answer tag names chapter #{chapter} with no koan file"}]
  end

  defp exercise_errors(_line, _marker, _tag, nil), do: []

  defp exercise_errors(line, marker, tag, exercised) do
    if (marker.markup or marker.default != nil) and {marker.chapter, tag} not in exercised,
      do: [{line, "no koan of chapter #{marker.chapter} names #{tag} in exercises"}],
      else: []
  end

  defp width_errors(line, marker) do
    width = marker |> Markers.blank_line(marker.chapter) |> String.length()

    if width > @line_length,
      do: [{line, "generated blank is #{width} columns, over #{@line_length}: shorten the tag"}],
      else: []
  end

  defp stray_errors(source) do
    source.lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {text, line} ->
      cond do
        Markers.parse_line(text) != nil -> []
        text =~ ~r/<!-- (>>> answer|<<< -->)/ -> [{line, "markup marker not on its own line"}]
        text =~ ~r{// (>>> answer|<<<)} -> [{line, "// marker not on its own line"}]
        true -> []
      end
    end)
  end

  defp svelte_errors(%{svelte: false}), do: []

  defp svelte_errors(source) do
    tags = Regex.scan(~r/<script\b([^>]*)>/, source.text, return: :index)
    message = ~s|component has no <script lang="ts">|

    if tags == [] do
      [{1, message}]
    else
      for [{at, _}, {from, len}] <- tags,
          not Regex.match?(@ts_script, binary_part(source.text, from, len)),
          do: {Lexer.line_of(source.text, at), message}
    end
  end
end
