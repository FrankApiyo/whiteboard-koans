defmodule Koans.SourceCheck do
  @moduledoc false

  alias Koans.{Gen, Markers}
  alias Koans.SourceCheck.NeverBlank

  @def_kinds [:def, :defp, :defmacro, :defmacrop]
  @receive_macros [:assert_receive, :assert_received, :refute_receive, :refute_received]
  @max_stub_clauses 3
  @line_length 98

  @outside "value blank outside a koan body"
  @pattern "value blank in a pattern"
  @negated "value blank compared with != or under refute"

  def check(text, path, opts \\ []) do
    markers = Markers.scan(text)
    marker_errors = marker_errors(markers, path, opts)
    pairing_errors = pairing_errors(markers)

    stray =
      for line <- Markers.stray_heex_lines(text), do: {line, "heex marker not on its own line"}

    tree_errors =
      if Path.extname(path) == ".heex", do: [], else: tree_errors(text, path, pairing_errors)

    errors =
      (marker_errors ++ pairing_errors ++ stray ++ tree_errors)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn {line, rule} -> "#{path}:#{line}: #{rule}" end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp tree_errors(text, path, pairing_errors) do
    case Code.string_to_quoted(text, columns: true, token_metadata: true, file: path) do
      {:ok, ast} -> ast_errors(ast, text, pairing_errors)
      {:error, {location, message, token}} -> [syntax_error(location, message, token)]
    end
  end

  defp ast_errors(ast, text, pairing_errors) do
    blocks = if pairing_errors == [], do: Markers.blocks(text), else: []

    walk(ast, %{koan: false, pattern: false, negated: false}, []) ++
      Enum.flat_map(blocks, &stub_errors(&1, ast)) ++
      NeverBlank.errors(blocks, ast) ++
      meditation_errors(blocks, ast)
  end

  defp syntax_error(location, message, token) do
    line = if is_list(location), do: Keyword.get(location, :line, 1), else: location
    message = if is_tuple(message), do: Tuple.to_list(message) |> Enum.join(), else: message
    {line, "syntax error: #{message}#{token}"}
  end

  defp marker_errors(markers, path, opts) do
    chapters = Keyword.get(opts, :chapters)

    Enum.flat_map(markers, fn
      {line, :malformed} ->
        [{line, "malformed answer marker"}]

      {line, %{kind: :open} = marker} ->
        default_errors(line, marker) ++
          tag_errors(line, marker, path, chapters) ++ width_errors(line, marker)

      _ ->
        []
    end)
  end

  defp tag_errors(line, %{chapter: nil}, path, _chapters), do: untagged_error(line, path)

  defp tag_errors(line, %{chapter: chapter}, _path, chapters),
    do: chapter_error(line, chapter, chapters)

  defp width_errors(line, marker) do
    width = marker |> Gen.blank_line(marker.chapter || "NN") |> String.length()

    if width > @line_length,
      do: [{line, "generated blank is #{width} columns, over #{@line_length}: shorten the tag"}],
      else: []
  end

  defp default_errors(_line, %{default: nil}), do: []

  defp default_errors(line, %{heex: true}),
    do: [{line, "default is not allowed on a HEEx marker"}]

  defp default_errors(line, %{default: ""}), do: [{line, "empty default expression"}]

  defp default_errors(line, %{default: default}) do
    case Code.string_to_quoted(default) do
      {:ok, _} -> []
      {:error, _} -> [{line, "default is not a valid expression"}]
    end
  end

  defp untagged_error(line, path) do
    if Regex.match?(~r{(^|/)test/koans/}, path),
      do: [],
      else: [{line, "answer marker needs a NN: tag"}]
  end

  defp chapter_error(_line, _chapter, nil), do: []

  defp chapter_error(line, chapter, chapters) do
    if chapter in chapters,
      do: [],
      else: [{line, "answer tag names chapter #{chapter} with no koan file"}]
  end

  defp walk({:_a, meta, args}, st, acc) when is_list(args) do
    line = meta[:line]

    [
      {not st.koan, @outside},
      {st.pattern, @pattern},
      {st.negated, @negated}
    ]
    |> Enum.reduce(acc, fn
      {true, rule}, acc -> [{line, rule} | acc]
      {false, _}, acc -> acc
    end)
  end

  defp walk({:koan, _, [meditation, [do: body]]}, st, acc) do
    acc = walk(meditation, st, acc)
    walk(body, %{koan: true, pattern: false, negated: false}, acc)
  end

  defp walk({:=, _, [left, right]}, st, acc), do: both(left, right, st, acc)
  defp walk({:<-, _, [left, right]}, st, acc), do: both(left, right, st, acc)
  defp walk({:match?, _, [pattern, expr]}, st, acc), do: both(pattern, expr, st, acc)

  defp walk({:->, _, [heads, body]}, st, acc) do
    acc = walk(heads, %{st | pattern: true}, acc)
    walk(body, st, acc)
  end

  defp walk({kind, _, [head | rest]}, st, acc) when kind in @def_kinds do
    acc = walk(head, %{st | pattern: true}, acc)
    walk(rest, st, acc)
  end

  defp walk({name, _, args}, st, acc) when name in @receive_macros and is_list(args),
    do: walk(args, %{st | pattern: true}, acc)

  defp walk({name, _, args}, st, acc) when name in [:!=, :!==, :refute] and is_list(args),
    do: walk(args, %{st | negated: true}, acc)

  defp walk({form, _, args}, st, acc) when is_list(args), do: walk(args, st, walk(form, st, acc))
  defp walk({a, b}, st, acc), do: walk(b, st, walk(a, st, acc))
  defp walk(list, st, acc) when is_list(list), do: Enum.reduce(list, acc, &walk(&1, st, &2))
  defp walk(_leaf, _st, acc), do: acc

  defp both(pattern, expr, st, acc) do
    acc = walk(pattern, %{st | pattern: true}, acc)
    walk(expr, st, acc)
  end

  defp pairing_errors(markers) do
    {errors, open} =
      markers
      |> Enum.reject(&(elem(&1, 1) == :malformed))
      |> Enum.reduce({[], nil}, fn
        {n, %{kind: :open}}, {errs, nil} -> {errs, n}
        {n, %{kind: :open}}, {errs, _} -> {[{n, "nested answer marker"} | errs], n}
        {_, %{kind: :close}}, {errs, open} when open != nil -> {errs, nil}
        {n, %{kind: :close}}, {errs, nil} -> {[{n, "unmatched answer marker"} | errs], nil}
      end)

    if open, do: [{open, "unmatched answer marker"} | errors], else: errors
  end

  defp stub_errors(%{head: nil}, _ast), do: []

  defp stub_errors(%{from: from, to: to, head: head}, ast) do
    case Code.string_to_quoted(head) do
      {:ok, {kind, _, [signature]}} when kind in @def_kinds ->
        {name, arity} = name_arity(signature)
        clauses = clauses(ast, name, arity)
        in_block = Enum.filter(clauses, &(&1.line > from and &1.line < to))
        module_clauses = clauses_of_enclosing_module(clauses, ast, from, to)

        cond do
          length(in_block) > @max_stub_clauses ->
            [{from, "stub block holds more than three clauses"}]

          in_block == [] or length(in_block) != length(module_clauses) ->
            [{from, "stub block does not cover every clause of #{name}/#{arity}"}]

          true ->
            []
        end

      _ ->
        [{from, "stub head is not a def signature"}]
    end
  end

  defp name_arity({:when, _, [signature | _]}), do: name_arity(signature)
  defp name_arity({name, _, args}) when is_list(args), do: {name, length(args)}
  defp name_arity({name, _, _}), do: {name, 0}

  defp clauses(ast, name, arity) do
    {_, found} =
      Macro.prewalk(ast, [], fn
        {kind, meta, [head | _]} = node, acc when kind in @def_kinds ->
          case safe_name_arity(head) do
            {^name, ^arity} -> {node, [%{line: meta[:line]} | acc]}
            _ -> {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp safe_name_arity({:when, _, [signature | _]}), do: safe_name_arity(signature)

  defp safe_name_arity({name, _, args}) when is_atom(name) and is_list(args),
    do: {name, length(args)}

  defp safe_name_arity(_), do: nil

  defp clauses_of_enclosing_module(clauses, ast, from, to) do
    case enclosing_module(ast, from, to) do
      nil -> clauses
      {first, last} -> Enum.filter(clauses, &(&1.line > first and &1.line < last))
    end
  end

  defp enclosing_module(ast, from, to) do
    {_, modules} =
      Macro.prewalk(ast, [], fn
        {:defmodule, meta, _} = node, acc ->
          first = meta[:line]
          last = get_in(meta, [:end, :line])

          if last && first < from && last > to,
            do: {node, [{first, last} | acc]},
            else: {node, acc}

        node, acc ->
          {node, acc}
      end)

    Enum.max_by(modules, &elem(&1, 0), fn -> nil end)
  end

  defp meditation_errors([], _ast), do: []

  defp meditation_errors(blocks, ast) do
    {_, {koans, implement}} =
      Macro.prewalk(ast, {false, false}, fn
        {:koan, _, [meditation, _]} = node, {_, found} when is_binary(meditation) ->
          {node, {true, found or String.contains?(meditation, "Implement")}}

        node, acc ->
          {node, acc}
      end)

    if koans and not implement do
      [{hd(blocks).from, "file has a code block but no meditation containing Implement"}]
    else
      []
    end
  end
end
