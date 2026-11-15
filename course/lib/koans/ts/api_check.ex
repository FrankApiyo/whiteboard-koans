defmodule Koans.Ts.ApiCheck do
  @moduledoc false

  alias Koans.ApiCheck, as: ElixirApiCheck
  alias Koans.Ts.{Lexer, Markers, Values}

  @receivers ~w(Math Number Object Array JSON crypto window document performance ctx canvas live event screen fireEvent)
  @runes ~w($state.raw $state.snapshot $state $derived.by $derived $effect $props)
  @globals ~w(requestAnimationFrame cancelAnimationFrame setTimeout clearTimeout)
  @ts_extensions ~w(.ts .js .svelte)
  @import ~r/\bimport\s+(?!type\b)([\w$*{}\s,]+?)\s+from\s+["']([^"']+)["']/
  @elixir_errors [SyntaxError, TokenMissingError, MismatchedDelimiterError]

  def missing(chapters, sources \\ []) do
    lessons = Enum.map(chapters, fn {nn, text} -> {nn, any_lesson(text)} end)

    needed =
      Enum.flat_map(chapters, fn {nn, text} ->
        if ts?(text), do: calls(text, nn, false), else: []
      end) ++
        Enum.flat_map(sources, fn {path, text} ->
          if Path.extname(path) in @ts_extensions,
            do: calls(text, nil, Path.extname(path) == ".svelte"),
            else: []
        end)

    needed
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.reject(fn {nn, call} -> taught?(taught_through(lessons, nn), call) end)
    |> Enum.map(fn {nn, call} -> "#{nn}: #{call.display} not in this or an earlier lesson" end)
    |> Enum.uniq()
  end

  def lesson(text) do
    case lesson_lines(text) do
      {:ok, lines} -> Enum.join(lines, "\n")
      _ -> ""
    end
  end

  def lesson_problems(text) do
    case lesson_lines(text) do
      {:ok, lines} ->
        starred =
          for {line, n} <- Enum.with_index(lines, 2),
              String.starts_with?(String.trim_leading(line), "*"),
              do: "lesson line #{n} starts with *"

        starred ++ ElixirApiCheck.lesson_problems(Enum.join(lines, "\n"))

      {:error, problem} ->
        [problem]
    end
  end

  defp lesson_lines(text) do
    case String.split(text, "\n") do
      ["/*" | rest] ->
        case Enum.find_index(rest, &(String.trim(&1) == "*/")) do
          nil -> {:error, "lesson block has no */ line"}
          close -> {:ok, Enum.take(rest, close)}
        end

      _ ->
        {:error, "lesson must open with /* on line 1"}
    end
  end

  defp any_lesson(text) do
    if ts?(text), do: lesson(text), else: ElixirApiCheck.lesson(text)
  rescue
    _ in @elixir_errors -> ""
  end

  defp ts?(text), do: String.starts_with?(text, "/*") or not elixir?(text)

  defp elixir?(text), do: match?({:ok, _}, Code.string_to_quoted(text))

  defp taught_through(lessons, nn),
    do: lessons |> Enum.filter(fn {m, _} -> m <= nn end) |> Enum.map_join("\n", &elem(&1, 1))

  defp taught?(lesson, %{name: name, exact: exact}) do
    before = if exact, do: "(?<![\\w$.])", else: "(?<![\\w$])"
    Regex.match?(Regex.compile!(before <> Regex.escape(name <> "(")), lesson)
  end

  defp calls(text, file_chapter, svelte) do
    imported = imports(text)
    mask = if svelte, do: Lexer.scan_svelte(text).mask, else: Lexer.scan(text).mask

    for {nn, snippet} <- answers(text, mask, file_chapter),
        nn != nil,
        call <- snippet_calls(snippet, imported),
        do: {nn, call}
  end

  defp answers(text, mask, file_chapter) do
    lines = String.split(text, "\n")
    masked = String.split(mask, "\n")

    blocks =
      for {from, to, marker} <- blocks(text) do
        source = if marker.markup, do: lines, else: masked
        {marker.chapter, source |> Enum.slice(from, to - from - 1) |> Enum.join("\n")}
      end

    values =
      if file_chapter,
        do: for({_, inner} <- Values.answers(text), do: {file_chapter, Lexer.scan(inner).mask}),
        else: []

    blocks ++ values
  end

  defp blocks(text) do
    text
    |> Markers.scan()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn
      [{from, %{kind: :open} = open}, {to, %{kind: :close}}] -> [{from, to, open}]
      _ -> []
    end)
  end

  defp imports(text) do
    for [_, clause, spec] <- Regex.scan(@import, text),
        bare?(spec),
        binding <- clause_bindings(clause),
        do: binding
  end

  defp bare?(spec), do: not String.starts_with?(spec, [".", "/", "@koans/", "$"])

  defp clause_bindings(clause) do
    named =
      case Regex.run(~r/\{([^}]*)\}/, clause) do
        [_, inner] -> inner |> String.split(",") |> Enum.flat_map(&named_binding/1)
        nil -> []
      end

    namespace =
      for [_, local] <- Regex.scan(~r/\*\s+as\s+([\w$]+)/, clause), do: {local, local}

    default =
      case Regex.run(~r/\A\s*([\w$]+)\s*(?:,|\z)/, clause) do
        [_, local] -> [{local, local}]
        nil -> []
      end

    named ++ namespace ++ default
  end

  defp named_binding(part) do
    case part |> String.trim() |> String.split(~r/\s+as\s+/) do
      ["type " <> _ | _] -> []
      [""] -> []
      [name] -> [{name, name}]
      [name, local] -> [{local, name}]
    end
  end

  defp snippet_calls(snippet, imported) do
    runes =
      for [_, rune] <- scan(~r/(?<![\w$.])(#{alternation(@runes)})\s*\(/, snippet),
          do: call(rune, rune, true)

    globals =
      for [_, name] <- scan(~r/(?<![\w$.])(#{alternation(@globals)})\s*\(/, snippet),
          do: call(name, name, false)

    members =
      for [_, receiver, name] <- scan(member(@receivers), snippet),
          do: call("#{receiver}.#{name}", name, false)

    imports =
      Enum.flat_map(imported, fn {local, name} ->
        direct =
          for _ <- scan(~r/(?<![\w$.])#{Regex.escape(local)}\s*\(/, snippet),
              do: call(name, name, false)

        direct ++
          for [_, receiver, member] <- scan(member([local]), snippet),
              do: call("#{receiver}.#{member}", member, false)
      end)

    runes ++ globals ++ members ++ imports
  end

  defp scan(pattern, snippet), do: Regex.scan(pattern, snippet)

  defp member(receivers),
    do: ~r/(?<![\w$])(#{alternation(receivers)})\s*\.\s*([A-Za-z_$][\w$]*)\s*\(/

  defp alternation(names), do: Enum.map_join(names, "|", &Regex.escape/1)

  defp call(display, name, exact), do: %{display: display, name: name, exact: exact}
end
