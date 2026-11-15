defmodule Koans.ApiCheck do
  @moduledoc false

  alias Koans.Markers

  @exempt_modules ~w(Kernel Kernel.SpecialForms ExUnit.Assertions ExUnit.Callbacks ExUnit.Case)
  @exempt_prefixes ["Easel.", "EaselWeb.", "Koans."]
  @exempt_roots ["Easel", "EaselWeb"]

  @api_entry ~r/^\s*(?:- )?(?:(?:[A-Z]\w*(?:\.[A-Z]\w*)*|:\w+)\.)?[a-z_]\w*[?!]?\/\d+(?![\w\/])/

  def missing(chapters, context \\ [], sources \\ []) do
    parsed =
      chapters
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {nn, text} -> {nn, text, parse(text)} end)

    lessons =
      Enum.map(parsed, fn {nn, _, ast} -> {nn, lesson_of(ast)} end) ++
        Enum.flat_map(context, &context_lesson/1)

    needed =
      Enum.flat_map(parsed, fn {nn, text, ast} -> answer_calls(text, ast, nn) end) ++
        Enum.flat_map(sources, &source_calls/1)

    needed
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reject(fn {nn, call} -> mentions?(taught_through(lessons, nn), call) end)
    |> Enum.map(fn {nn, call} -> "#{nn}: #{call} not in this or an earlier lesson" end)
    |> Enum.uniq()
  end

  defp taught_through(lessons, nn),
    do: lessons |> Enum.filter(fn {m, _} -> m <= nn end) |> Enum.map_join("\n", &elem(&1, 1))

  defp source_calls({path, text}) do
    if Path.extname(path) in [".ex", ".exs"], do: answer_calls(text, parse(text), nil), else: []
  end

  def context_chapters(all, selected) do
    bound = Enum.max(selected, fn -> "00" end)
    Enum.filter(all, &(&1 not in selected and &1 < bound))
  end

  def lesson_problems(lesson) do
    lines = lesson |> String.trim_trailing() |> String.split("\n")
    api = Enum.find_index(lines, &(String.trim(&1) == "API you'll use"))
    picture = Enum.find_index(lines, &String.starts_with?(&1, "Picture: "))

    cond do
      api == nil -> ["no API you'll use line"]
      picture == nil -> ["no Picture: line"]
      picture < api -> ["Picture: comes before API you'll use"]
      true -> body_problems(lines, api, picture)
    end
  end

  defp body_problems(lines, api, picture) do
    body = lines |> Enum.take(api) |> Enum.join("\n") |> String.trim() |> String.split("\n")

    entries =
      lines
      |> Enum.slice(api + 1, picture - api - 1)
      |> Enum.count(&Regex.match?(@api_entry, &1))

    List.flatten([
      if(length(body) in 10..30,
        do: [],
        else: ["lesson body has #{length(body)} lines, want 10 to 30"]
      ),
      if(entries <= 15, do: [], else: ["API list has #{entries} entries, want at most 15"])
    ])
  end

  def lesson(text), do: text |> parse() |> lesson_of()

  defp mentions?(taught, call),
    do: Regex.match?(~r/(?<![\w.])#{Regex.escape(call)}(?![\w?!])/, taught)

  defp context_lesson({nn, text}) do
    [{nn, lesson(text)}]
  rescue
    _ in [SyntaxError, TokenMissingError, MismatchedDelimiterError] -> []
  end

  defp parse(text), do: Code.string_to_quoted!(text, columns: true, token_metadata: true)

  defp lesson_of(ast) do
    {_, found} =
      Macro.prewalk(ast, nil, fn
        {:defmodule, _, [_, [do: body]]} = node, nil -> {node, koans_module_doc(body)}
        node, acc -> {node, acc}
      end)

    found || ""
  end

  defp koans_module_doc(body) do
    {_, uses_koans} =
      Macro.prewalk(body, false, fn
        {:use, _, [{:__aliases__, _, [:Koans]} | _]} = node, _ -> {node, true}
        node, acc -> {node, acc}
      end)

    if uses_koans do
      body
      |> List.wrap()
      |> Enum.flat_map(fn
        {:__block__, _, exprs} -> exprs
        expr -> [expr]
      end)
      |> Enum.find_value(fn
        {:@, _, [{:moduledoc, _, [doc]}]} -> doc_text(doc)
        _ -> nil
      end)
    end
  end

  defp doc_text(doc) when is_binary(doc), do: doc
  defp doc_text({:sigil_S, _, [{:<<>>, _, [doc]}, _]}) when is_binary(doc), do: doc
  defp doc_text({:<<>>, _, parts}), do: Enum.filter(parts, &is_binary/1) |> Enum.join()
  defp doc_text(_), do: ""

  defp answer_calls(text, ast, default_nn) do
    aliases = aliases(ast)
    own = own_modules(ast)
    blocks = text |> Markers.blocks() |> Enum.reject(& &1.heex)
    all_calls = calls_with_lines(ast, aliases)

    inline =
      if default_nn do
        {_, found} =
          Macro.prewalk(ast, [], fn
            {:_a, _, args} = node, acc when is_list(args) -> {node, [calls(args, aliases) | acc]}
            node, acc -> {node, acc}
          end)

        for call <- List.flatten(found), do: {default_nn, call}
      else
        []
      end

    in_blocks =
      for block <- blocks,
          {call, line} <- all_calls,
          line > block.from and line < block.to,
          do: {block.chapter || default_nn, call}

    (inline ++ in_blocks)
    |> Enum.reject(fn {_nn, call} -> exempt?(call, own) end)
    |> Enum.map(fn {nn, call} -> {nn, elem(call, 2)} end)
    |> Enum.uniq()
  end

  defp calls(ast, aliases), do: ast |> calls_with_lines(aliases) |> Enum.map(&elem(&1, 0))

  defp calls_with_lines(ast, aliases) do
    {_, found} =
      Macro.prewalk(ast, [], fn
        {{:., meta, [mod, fun]}, _, args} = node, acc when is_atom(fun) and is_list(args) ->
          case module_name(mod, aliases) do
            nil -> {node, acc}
            name -> {node, [{{name, fun, "#{name}.#{fun}"}, meta[:line]} | acc]}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(found)
  end

  defp module_name({:__aliases__, _, [{:__MODULE__, _, _} | _]}, _aliases), do: nil

  defp module_name({:__aliases__, _, [first | rest] = parts}, aliases) when is_atom(first) do
    case aliases do
      %{^first => full} -> Enum.join([full | Enum.map(rest, &to_string/1)], ".")
      _ -> Enum.map_join(parts, ".", &to_string/1)
    end
  end

  defp module_name(mod, _aliases) when is_atom(mod) and mod not in [nil, true, false],
    do: inspect(mod)

  defp module_name(_other, _aliases), do: nil

  defp exempt?({name, _fun, _text}, own) do
    name in @exempt_modules or name in @exempt_roots or name in own or
      Enum.any?(@exempt_prefixes, &String.starts_with?(name, &1))
  end

  defp aliases(ast) do
    {_, found} =
      Macro.prewalk(ast, %{}, fn
        {:alias, _, [{:__aliases__, _, parts}, opts]} = node, acc when is_list(opts) ->
          short = Keyword.get(opts, :as) |> alias_short(parts)
          {node, Map.put(acc, short, Enum.map_join(parts, ".", &to_string/1))}

        {:alias, _, [{:__aliases__, _, parts}]} = node, acc ->
          {node, Map.put(acc, List.last(parts), Enum.map_join(parts, ".", &to_string/1))}

        {:alias, _, [{{:., _, [{:__aliases__, _, prefix}, :{}]}, _, children}]} = node, acc ->
          added =
            for {:__aliases__, _, child} <- children, into: %{} do
              {List.last(child), Enum.map_join(prefix ++ child, ".", &to_string/1)}
            end

          {node, Map.merge(acc, added)}

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp alias_short({:__aliases__, _, [short]}, _parts), do: short
  defp alias_short(_none, parts), do: List.last(parts)

  defp own_modules(ast) do
    {_, names} =
      Macro.prewalk(ast, [], fn
        {:defmodule, _, [{:__aliases__, _, parts}, _]} = node, acc ->
          {node, [Enum.map_join(parts, ".", &to_string/1) | acc]}

        node, acc ->
          {node, acc}
      end)

    names
  end
end
