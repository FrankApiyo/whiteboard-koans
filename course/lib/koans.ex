defmodule Koans do
  defmacro __using__(opts) do
    case_module = Keyword.get(opts, :case, ExUnit.Case)

    quote do
      use unquote(case_module), async: false
      import Koans, only: [koan: 2, __: 0, __: 1, __: 2]
    end
  end

  defmacro koan(meditation, do: body) do
    file = __CALLER__.file
    line = __CALLER__.line
    name = "#{chapter(file)}:#{line}"
    body = replace_value_blanks(body, file)

    wrapped =
      quote do
        Koans.run(unquote(chapter(file)), fn -> Koans.keep_frame(unquote(body)) end)
      end

    quote bind_quoted: [
            file: file,
            line: line,
            name: name,
            meditation: meditation,
            wrapped: Macro.escape(wrapped)
          ] do
      test_name =
        ExUnit.Case.register_test(__MODULE__, file, line, :test, name, meditation: meditation)

      def unquote(test_name)(_context), do: unquote(wrapped)
    end
  end

  defmacro __() do
    code_blank(__CALLER__, nil)
  end

  defmacro __(tag) do
    code_blank(__CALLER__, tag)
  end

  defmacro __(tag, default) do
    {used, file, line, mfa} = blank_site(__CALLER__)

    quote do
      _ = {unquote_splicing(used)}

      Koans.Hits.record_soft(
        unquote(file),
        unquote(line),
        unquote(tag),
        unquote(Macro.escape(mfa))
      )

      unquote(default)
    end
  end

  # Keeps the body out of tail position so a failing last expression stays in the stacktrace.
  def keep_frame(value), do: value

  def run(chapter, fun) do
    Koans.Hits.clear()

    try do
      fun.()
    catch
      kind, reason ->
        original_stacktrace = __STACKTRACE__

        case blamed_hit(chapter) do
          {file, line, tag, mfa} -> raise_hit(file, line, tag, mfa)
          nil -> :erlang.raise(kind, reason, original_stacktrace)
        end
    end
  end

  defp blamed_hit(chapter) do
    Koans.Hits.last() || Enum.find(Koans.Hits.soft(), &(tag_chapter(elem(&1, 2)) == chapter))
  end

  defp tag_chapter(tag) when is_binary(tag) do
    case Regex.run(~r/^(\d+)/, tag) do
      [_, digits] -> digits
      nil -> nil
    end
  end

  defp tag_chapter(_tag), do: nil

  defp raise_hit(file, line, tag, mfa) do
    stacktrace = [{__MODULE__, :koan, 0, [file: String.to_charlist(file), line: line]}]

    exception = %Koans.Blank{
      message: Koans.Blank.code_message(),
      file: file,
      line: line,
      tag: tag,
      mfa: mfa
    }

    :erlang.raise(:error, exception, stacktrace)
  end

  defp code_blank(caller, tag) do
    {used, file, line, mfa} = blank_site(caller)

    quote do
      _ = {unquote_splicing(used)}
      Koans.Blank.code!(unquote(file), unquote(line), unquote(tag), unquote(Macro.escape(mfa)))
    end
  end

  defp blank_site(caller) do
    used =
      caller.versioned_vars
      |> Map.keys()
      |> Enum.flat_map(fn
        {name, nil} ->
          if String.starts_with?(Atom.to_string(name), "_"), do: [], else: [Macro.var(name, nil)]

        _ ->
          []
      end)

    {used, caller.file, caller.line, caller_mfa(caller)}
  end

  defp caller_mfa(%{module: module, function: {name, arity}}), do: {module, name, arity}
  defp caller_mfa(_caller), do: nil

  defp replace_value_blanks(body, file) do
    Macro.prewalk(body, fn
      {:__, meta, ctx} when is_atom(ctx) ->
        quote do
          Koans.Blank.value!(unquote(file), unquote(meta[:line]))
        end

      node ->
        node
    end)
  end

  defp chapter(file) do
    case Regex.run(~r/^(\d+)/, Path.basename(file)) do
      [_, digits] -> digits
      nil -> "00"
    end
  end
end
