defmodule Koans.Ts.SourceCheck.FunctionBody do
  @moduledoc false

  alias Koans.Ts.SourceCheck

  @control ~w(if for while switch catch with do else try finally)
  @type_context [":", "=>", "|", "&", ",", "<", "("]

  def whole?(block, source) do
    open_at = elem(source.starts, block.from - 1)
    start = SourceCheck.script_start(source, open_at)

    close_end =
      elem(source.starts, block.to - 1) + byte_size(SourceCheck.line_text(source, block.to))

    with {:ok, brace} <- enclosing_brace(source.mask, open_at - 1, start, 0),
         {:ok, close} <- matching_close(source.mask, brace + 1, 0) do
      function_head?(binary_part(source.mask, start, brace - start)) and
        blank?(source.mask, brace + 1, open_at) and blank?(source.mask, close_end, close)
    else
      :error -> false
    end
  end

  defp enclosing_brace(_mask, i, start, _depth) when i < start, do: :error

  defp enclosing_brace(mask, i, start, depth) do
    case :binary.at(mask, i) do
      ?{ when depth == 0 -> {:ok, i}
      ?{ -> enclosing_brace(mask, i - 1, start, depth - 1)
      ?} -> enclosing_brace(mask, i - 1, start, depth + 1)
      _ -> enclosing_brace(mask, i - 1, start, depth)
    end
  end

  defp matching_close(mask, i, _depth) when i >= byte_size(mask), do: :error

  defp matching_close(mask, i, depth) do
    case :binary.at(mask, i) do
      ?} when depth == 0 -> {:ok, i}
      ?} -> matching_close(mask, i + 1, depth - 1)
      ?{ -> matching_close(mask, i + 1, depth + 1)
      _ -> matching_close(mask, i + 1, depth)
    end
  end

  defp blank?(_mask, from, to) when from >= to, do: true
  defp blank?(mask, from, to), do: String.trim(binary_part(mask, from, to - from)) == ""

  defp function_head?(before) do
    head = String.trim_trailing(before)
    String.ends_with?(head, "=>") or params_head?(head, byte_size(head))
  end

  defp params_head?(head, stop) do
    with {:ok, close} <- last_close_paren(head, stop),
         {:ok, open} <- matching_open(head, close - 1, 0) do
      prefix = head |> binary_part(0, open) |> String.trim_trailing()

      if String.ends_with?(prefix, @type_context),
        do: params_head?(head, open),
        else: named_params?(prefix, binary_part(head, close + 1, byte_size(head) - close - 1))
    else
      :error -> false
    end
  end

  defp named_params?(prefix, tail) do
    tail = String.trim(tail)

    case Regex.run(~r/([\w$]+)\s*(?:<[^()]*>)?\z/, prefix) do
      [_, word] -> word not in @control and (tail == "" or String.starts_with?(tail, ":"))
      nil -> false
    end
  end

  defp last_close_paren(head, stop) do
    case :binary.matches(binary_part(head, 0, stop), ")") do
      [] -> :error
      matches -> {:ok, matches |> List.last() |> elem(0)}
    end
  end

  defp matching_open(_head, i, _depth) when i < 0, do: :error

  defp matching_open(head, i, depth) do
    case :binary.at(head, i) do
      ?( when depth == 0 -> {:ok, i}
      c when c in ~c"([{" -> matching_open(head, i - 1, depth - 1)
      c when c in ~c")]}" -> matching_open(head, i - 1, depth + 1)
      _ -> matching_open(head, i - 1, depth)
    end
  end
end
