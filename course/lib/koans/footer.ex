defmodule Koans.Footer do
  @width 80

  def render(%{passed: passed, total: total, ran: ran, failure: failure, scope: scope}) do
    body(passed, total, ran, failure, scope)
  end

  defp body(passed, total, _ran, %{} = failure, scope) do
    diff = if failure.diff, do: failure.diff <> "\n", else: ""

    meditation =
      failure.meditation
      |> String.split("\n")
      |> Enum.map_join("\n", &("    " <> &1))

    diff <>
      separator("The master says") <>
      "\n#{locations(failure)}\n#{meditation}\n" <>
      "#{passed} of #{total} #{noun(scope)} answered."
  end

  defp body(_passed, _total, 0, nil, _scope) do
    "No koan at that line: put the cursor inside a koan, or run the file."
  end

  defp body(passed, total, ran, nil, :all) when ran >= total and passed == total do
    separator("Enlightenment") <>
      "\nAll #{total} koans pass. Start again with: mix koans.reset all"
  end

  defp body(passed, total, ran, nil, scope) when ran >= total and passed == total do
    "All #{total} #{noun(scope)} pass. Run mix koans for the whole course."
  end

  defp body(passed, total, _ran, nil, scope) do
    "#{passed} of #{total} #{noun(scope)} answered. Run the whole suite for the rest."
  end

  defp noun(:all), do: "koans"
  defp noun(:elixir), do: "Elixir koans"
  defp noun(:typescript), do: "TypeScript koans"

  def total(dir) do
    dir
    |> Path.join("*_test.exs")
    |> Path.wildcard()
    |> Enum.map(fn file ->
      ~r/^\s*koan\s+"/m |> Regex.scan(File.read!(file)) |> length()
    end)
    |> Enum.sum()
  end

  def kind(_kind, %ExUnit.TimeoutError{}), do: "timeout"

  def kind(kind, reason) do
    case {find_blank(reason), kind, reason} do
      {%Koans.Blank{}, _, _} -> "Koans.Blank"
      {_, :error, %{__struct__: module}} -> inspect(module)
      {_, :error, _} -> "error"
      {_, :exit, _} -> "exit"
      {_, other, _} -> if is_atom(other), do: to_string(other), else: "exit"
    end
  end

  @doc """
  A failure from a linked process arrives as `{{:EXIT, pid}, {exception, stacktrace}, []}`.
  Unwraps it to the exception it carries, unless a blank is inside, which keeps its own path.
  """
  def unwrap({{:EXIT, _pid}, {exception, inner}, _} = failure) when is_list(inner) do
    if is_exception(exception) and find_blank(exception) == nil,
      do: {:error, exception, inner},
      else: failure
  end

  def unwrap(failure), do: failure

  def location(test, error, stacktrace) do
    case find_blank(error) do
      %Koans.Blank{file: file, line: line} -> {file, line}
      nil -> from_stacktrace(test, error, stacktrace)
    end
  end

  defp from_stacktrace(test, error, stacktrace) do
    file = test.tags.file

    frame_line =
      if match?(%ExUnit.TimeoutError{}, error) do
        nil
      else
        Enum.find_value(stacktrace, fn
          {_m, _f, _a, loc} when is_list(loc) ->
            if same_file?(loc[:file], file), do: loc[:line]

          _ ->
            nil
        end)
      end

    {file, frame_line || test.tags.line}
  end

  defp same_file?(frame_file, file),
    do: Path.expand(to_string(frame_file)) == Path.expand(file)

  def earliest([]), do: nil

  def earliest(failures) do
    failures |> Enum.min_by(& &1.sort_key) |> Map.delete(:sort_key)
  end

  def blank(reason), do: find_blank(reason)

  def write(reason) do
    case find_blank(reason) do
      %Koans.Blank{mfa: mfa, file: file, line: line} when mfa != nil ->
        %{path: Path.relative_to_cwd(file), line: line, where: mfa}

      _ ->
        nil
    end
  end

  defp find_blank(%Koans.Blank{} = blank), do: blank
  defp find_blank(%{__struct__: Plug.Conn.WrapperError, reason: reason}), do: find_blank(reason)
  defp find_blank(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> find_blank()
  defp find_blank([head | tail]), do: find_blank(head) || find_blank_tail(tail)
  defp find_blank(_), do: nil

  defp find_blank_tail(tail) when is_list(tail), do: find_blank(tail)
  defp find_blank_tail(_), do: nil

  defp locations(%{write: %{path: path, line: line, where: where}} = failure) do
    "Write:          #{path}:#{line}#{where_suffix(where)}\n" <>
      "Exercised by:   #{failure.path}:#{failure.line}"
  end

  defp locations(failure), do: "Meditate on #{failure.path}:#{failure.line}"

  def where_text({module, fun, arity}), do: "#{inspect(module)}.#{fun}/#{arity}"
  def where_text(tag) when is_binary(tag), do: tag

  defp where_suffix(nil), do: ""
  defp where_suffix(where), do: "  (#{where_text(where)})"

  defp separator(title) do
    padded = " #{title} "
    fill = @width - String.length(padded)
    left = div(fill, 2)
    String.duplicate("-", left) <> padded <> String.duplicate("-", fill - left)
  end
end
