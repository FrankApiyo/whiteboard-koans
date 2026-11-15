defmodule Koans.Gen do
  @moduledoc false

  alias Koans.Gen.{Imports, QuietImports, Reblank, Values}
  alias Koans.{Markers, Ts}

  @ts_extensions ~w(.ts .js .svelte)

  defdelegate write_all(root, only \\ nil), to: Koans.Gen.Project
  defdelegate reblank(learner_text, source_text, chapter, opts \\ []), to: Reblank, as: :run
  defdelegate blank_line(marker, chapter), to: Markers

  def learner(text, opts \\ []), do: render(text, :learner, opts)

  def solutions(text, opts \\ []), do: render(text, :solutions, opts)

  def partial(text, upto, opts \\ []) when upto in 0..99,
    do: render(text, {:partial, upto}, opts)

  def cold(text, opts \\ []) do
    meditation = if language(opts) == :ts, do: ~S/\s*test\(\s*"/, else: ~S/\s*koan\s+"/
    open = "^(" <> meditation <> ~S/(?:[^"\\]|\\.)*?)/

    text
    |> learner(opts)
    |> String.replace(Regex.compile!(open <> ~S/ Message shapes?: .*?\.(?=[\s"])/, "m"), "\\1")
    |> String.replace(Regex.compile!(open <> ~S/ 1\. (?:[^"\\]|\\.)*"/, "m"), "\\1\"")
  end

  def language(opts), do: if(Keyword.get(opts, :ext) in @ts_extensions, do: :ts, else: :elixir)

  def syntax(opts), do: if(language(opts) == :ts, do: Ts.Markers, else: Markers)

  defp render(text, mode, opts) do
    case language(opts) do
      :ts ->
        text
        |> render_blocks(mode, {Ts.Markers, nil, %{}})
        |> Ts.Values.replace(mode != :solutions)

      :elixir ->
        imports = if mode == :solutions, do: %{}, else: Imports.after_lines(text, opts)

        text
        |> render_blocks(mode, {Markers, Keyword.get(opts, :chapter), imports})
        |> Values.replace(mode != :solutions)
        |> then(&if mode == :solutions, do: &1, else: QuietImports.apply(&1))
    end
  end

  defp render_blocks(text, mode, {syntax, default_chapter, imports}) do
    ctx = {mode, syntax, default_chapter, imports}

    {out, open} =
      text
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.reduce({[], nil}, &block_line(&1, &2, ctx))

    if open, do: raise(ArgumentError, "line #{elem(open, 0)}: answer marker never closed")
    out |> Enum.reverse() |> Enum.join("\n")
  end

  defp block_line({line, number}, {out, open}, {_, syntax, _, _} = ctx) do
    case syntax.parse_line(line) do
      :malformed ->
        raise ArgumentError, "line #{number}: malformed answer marker"

      %{kind: :open} = marker ->
        if open, do: raise(ArgumentError, "line #{number}: nested answer marker")
        open_block(marker, number, out, ctx)

      %{kind: :close} = close ->
        close_block(syntax, close, number, open)
        {trim_filled_tail(out, open), nil}

      nil ->
        plain_line(line, number, out, open, ctx)
    end
  end

  defp open_block(marker, number, out, {mode, syntax, default_chapter, _imports}) do
    chapter = marker.chapter || default_chapter

    if chapter == nil and mode != :solutions,
      do: raise(ArgumentError, "line #{number}: answer without a chapter tag or file chapter")

    if message = syntax.default_error(marker),
      do: raise(ArgumentError, "line #{number}: #{message}")

    filled = filled?(mode, chapter)
    out = if filled, do: out, else: Enum.reverse(syntax.blank_lines(marker, chapter), out)
    {out, {number, marker, filled, length(out)}}
  end

  defp trim_filled_tail(out, {_, _, true, start}), do: drop_blank_tail(out, length(out) - start)
  defp trim_filled_tail(out, _open), do: out

  defp drop_blank_tail([line | rest] = out, added) when added > 0 do
    if String.trim(line) == "", do: drop_blank_tail(rest, added - 1), else: out
  end

  defp drop_blank_tail(out, _added), do: out

  defp close_block(syntax, close, number, nil),
    do:
      raise(
        ArgumentError,
        "line #{number}: #{syntax.close_text(close)} without an answer marker"
      )

  defp close_block(syntax, close, number, {_, opened, _, _}) do
    if syntax.form(close) != syntax.form(opened),
      do: raise(ArgumentError, "line #{number}: closing marker does not match its opening")
  end

  defp plain_line(line, number, out, open, {_, _, _, imports}) do
    cond do
      open != nil and not elem(open, 2) -> {out, open}
      true -> {push_with_imports(out, line, number, imports), open}
    end
  end

  defp push_with_imports(out, line, number, imports) do
    case imports do
      %{^number => block} -> Enum.reverse(block, [line | out])
      _ -> [line | out]
    end
  end

  defp filled?(:learner, _chapter), do: false
  defp filled?(:solutions, _chapter), do: true
  defp filled?({:partial, upto}, chapter), do: String.to_integer(chapter) <= upto
end
