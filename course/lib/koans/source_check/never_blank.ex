defmodule Koans.SourceCheck.NeverBlank do
  @moduledoc false

  @record_macros [:schema, :embedded_schema, :object, :input_object]
  @root_contexts [:query, :mutation, :subscription]
  @field_macros [:field, :arg]
  @router_macros [:pipeline, :scope, :live_session]
  @component_macros [:attr, :slot]
  @def_kinds [:def, :defp]

  def errors(blocks, ast) do
    constructs = ast |> statements(:module) |> Enum.concat(callback_constructs(ast))

    for block <- blocks,
        construct <- constructs,
        construct.first <= block.to and construct.last >= block.from,
        do: {block.from, "marker inside a never-a-blank construct: #{construct.label}"}
  end

  defp statements(body, context), do: body |> body_exprs() |> Enum.flat_map(&visit(&1, context))

  defp visit({:defmodule, _, [_, [do: body]]}, _context), do: statements(body, :module)

  defp visit({name, meta, args}, :module) when name in @record_macros and is_list(args),
    do: [span(meta, name) | statements(do_body(args), :fields)]

  defp visit({name, _, args}, :module) when name in @root_contexts and is_list(args),
    do: statements(do_body(args), :fields)

  defp visit({name, meta, args}, :fields) when name in @field_macros and is_list(args),
    do: [span(meta, name) | statements(do_body(args), :fields)]

  defp visit({name, meta, args}, :module) when name in @router_macros and is_list(args),
    do: [span(meta, name) | statements(do_body(args), :module)]

  defp visit({name, meta, args}, :module) when name in @component_macros and is_list(args),
    do: [span(meta, name) | statements(do_body(args), :module)]

  defp visit(_other, _context), do: []

  defp do_body(args) do
    case List.last(args) do
      list when is_list(list) -> if Keyword.keyword?(list), do: Keyword.get(list, :do), else: nil
      _ -> nil
    end
  end

  defp callback_constructs(ast) do
    {_, found} =
      Macro.prewalk(ast, [], fn
        {:defmodule, _, [_, [do: body]]} = node, acc -> {node, module_constructs(body) ++ acc}
        node, acc -> {node, acc}
      end)

    found
  end

  defp module_constructs(body) do
    exprs = body_exprs(body)
    defs = for {kind, meta, [head | _]} <- exprs, kind in @def_kinds, do: {head, meta}
    keys = Enum.map(defs, fn {head, meta} -> {head_key(head), meta} end)
    uses = for {:use, _, [{:__aliases__, _, parts} | _]} <- exprs, do: parts
    plug? = plug?(exprs, uses, defs)

    for {{name, arity}, meta} <- keys,
        label = callback_label(name, arity, plug?, uses),
        do: span(meta, label)
  end

  defp plug?(exprs, uses, defs) do
    [:Plug, :Builder] in uses or plug_behaviour?(exprs) or
      Enum.any?(defs, fn {head, _} -> conn_call?(head) end)
  end

  defp plug_behaviour?(exprs) do
    Enum.any?(exprs, fn
      {:@, _, [{:behaviour, _, [{:__aliases__, _, [:Plug]}]}]} -> true
      _ -> false
    end)
  end

  defp conn_call?({:when, _, [signature | _]}), do: conn_call?(signature)
  defp conn_call?({:call, _, [first, _]}), do: binds_conn?(first)
  defp conn_call?(_head), do: false

  defp binds_conn?({:conn, _, ctx}) when is_atom(ctx), do: true
  defp binds_conn?({:=, _, [left, right]}), do: binds_conn?(left) or binds_conn?(right)
  defp binds_conn?(_other), do: false

  defp callback_label(:init, 1, plug?, _uses), do: if(plug?, do: "def init/1 of a plug")

  defp callback_label(:start, 2, _plug?, uses),
    do: if([:Application] in uses, do: "Application.start/2")

  defp callback_label(name, arity, _plug?, uses)
       when {name, arity} in [middleware: 3, context: 1, plugins: 0],
       do: if([:Absinthe, :Schema] in uses, do: "Absinthe #{name}/#{arity}")

  defp callback_label(:static_paths, 0, _plug?, _uses), do: "static_paths/0"
  defp callback_label(_name, _arity, _plug?, _uses), do: nil

  defp body_exprs(nil), do: []
  defp body_exprs({:__block__, _, exprs}), do: exprs
  defp body_exprs(expr), do: [expr]

  defp head_key({:when, _, [signature | _]}), do: head_key(signature)
  defp head_key({name, _, args}) when is_list(args), do: {name, length(args)}
  defp head_key({name, _, _}), do: {name, 0}

  defp span(meta, label) do
    first = meta[:line]
    %{first: first, last: get_in(meta, [:end, :line]) || first, label: to_string(label)}
  end
end
