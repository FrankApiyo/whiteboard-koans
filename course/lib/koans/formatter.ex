defmodule Koans.Formatter do
  use GenServer

  alias Koans.Footer

  @initial %{passed: 0, ran: 0, failures: [], finished: [], blanks: [], records: []}

  def init(_opts), do: {:ok, @initial}

  def handle_cast({:test_finished, %ExUnit.Test{state: {kind, _}}}, state)
      when kind in [:excluded, :skipped] do
    {:noreply, state}
  end

  def handle_cast({:test_finished, %ExUnit.Test{state: nil, tags: %{doctest: _}}}, state) do
    {:noreply, state}
  end

  def handle_cast({:test_finished, %ExUnit.Test{state: nil} = test}, state) do
    {:noreply,
     %{
       state
       | passed: state.passed + 1,
         ran: state.ran + 1,
         finished: finish(state, test, "ok"),
         records: [passed_record(test) | state.records]
     }}
  end

  def handle_cast({:test_finished, %ExUnit.Test{state: {:failed, [first | _]}} = test}, state) do
    record_failure(state, test, first)
  end

  def handle_cast({:test_finished, %ExUnit.Test{state: {:invalid, module}} = test}, state) do
    record_failure(state, test, invalid_failure(module))
  end

  def handle_cast({:test_finished, _test}, state) do
    {:noreply, %{state | ran: state.ran + 1}}
  end

  def handle_cast({:suite_finished, _times}, state) do
    case System.get_env("KOANS_RESULTS") do
      nil -> print_footer(state)
      dir -> write_results(dir, state.records)
    end

    if verify?(), do: print_verify_lines(state)
    {:noreply, state}
  end

  def handle_cast(_event, state), do: {:noreply, state}

  defp print_footer(state) do
    IO.puts(
      "\n" <>
        Footer.render(%{
          passed: state.passed,
          total: Footer.total(koans_dir()),
          ran: state.ran,
          failure: Footer.earliest(state.failures),
          scope: :elixir
        })
    )
  end

  defp write_results(dir, records) do
    File.mkdir_p!(dir)

    lines =
      records
      |> Enum.sort_by(&{&1.file, &1.line})
      |> Enum.map(&(JSON.encode!(%{&1 | order: order(&1.file, &1.line)}) <> "\n"))

    File.write!(Path.join(dir, "ex.jsonl"), lines)
  end

  defp passed_record(test) do
    record(test, "ok", %{at: test.tags.line})
  end

  defp failed_record(test, reason, failure) do
    blank = Footer.blank(reason)

    record(test, if(blank, do: "blank", else: "fail"), %{
      at: failure.line,
      tag: blank && blank.tag,
      write: failure.write && %{failure.write | where: Footer.where_text(failure.write.where)},
      diff: failure.diff
    })
  end

  defp record(test, status, fields) do
    file = Path.relative_to_cwd(test.tags.file)

    Map.merge(
      %{
        kind: "ex",
        chapter: chapter(file),
        file: file,
        line: test.tags.line,
        order: nil,
        status: status,
        meditation: to_string(test.tags[:meditation]),
        at: test.tags.line,
        tag: nil,
        write: nil,
        diff: nil
      },
      fields
    )
  end

  defp chapter(file) do
    case Regex.run(~r/^(\d+)/, Path.basename(file)) do
      [_, digits] -> digits
      nil -> "00"
    end
  end

  defp order(file, line) do
    file
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.filter(fn {text, _} -> Regex.match?(~r/^\s*koan\s+"/, text) end)
    |> Stream.map(&elem(&1, 1))
    |> Enum.find_index(&(&1 == line))
    |> case do
      nil -> 0
      index -> index + 1
    end
  end

  defp record_failure(state, test, raw) do
    {kind, reason, _} = raw = Footer.unwrap(raw)
    failure = build_failure(test, raw)
    finished = finish(state, test, Footer.kind(kind, reason))

    {:noreply,
     %{
       state
       | ran: state.ran + 1,
         failures: [failure | state.failures],
         finished: finished,
         blanks: blank_entry(test, reason) ++ state.blanks,
         records: [failed_record(test, reason, failure) | state.records]
     }}
  end

  defp blank_entry(test, reason) do
    case Footer.blank(reason) do
      %Koans.Blank{} = blank -> [{Path.relative_to_cwd(test.tags.file), test.tags.line, blank}]
      nil -> []
    end
  end

  defp finish(state, test, kind) do
    [{kind, Path.relative_to_cwd(test.tags.file), test.tags.line} | state.finished]
  end

  defp koans_dir do
    case Mix.Project.config()[:test_paths] do
      [dir | _] -> dir
      _ -> "test/koans"
    end
  end

  defp verify?, do: System.get_env("KOANS_VERIFY") == "1"

  defp print_verify_lines(state) do
    state.finished
    |> Enum.sort_by(fn {_kind, file, line} -> {file, line} end)
    |> Enum.each(fn {kind, file, line} -> IO.puts("KOANS-TEST #{kind} #{file}:#{line}") end)

    state.blanks
    |> Enum.sort_by(fn {file, line, _blank} -> {file, line} end)
    |> Enum.each(&print_blank_line/1)

    case Footer.earliest(state.failures) do
      nil -> IO.puts("KOANS-RESULT ok")
      failure -> IO.puts("KOANS-RESULT #{failure.kind} #{failure.path}:#{failure.line}")
    end
  end

  defp print_blank_line({file, line, blank}) do
    at = "#{(blank.file && Path.relative_to_cwd(blank.file)) || "-"}:#{blank.line || 0}"
    IO.puts("KOANS-BLANK #{file}:#{line} #{at} #{blank.tag || "-"}")
  end

  defp invalid_failure(%{state: {:failed, [first | _]}}), do: first

  defp invalid_failure(other),
    do: {:error, %RuntimeError{message: "invalid: #{inspect(other)}"}, []}

  defp build_failure(test, {kind, reason, stacktrace}) do
    write = Footer.write(reason)

    {file, line} =
      if write,
        do: {test.tags.file, test.tags.line},
        else: Footer.location(test, reason, stacktrace)

    %{
      path: Path.relative_to_cwd(file),
      line: line,
      write: write,
      meditation: to_string(test.tags[:meditation]),
      diff: failure_text(kind, reason, stacktrace),
      kind: Footer.kind(kind, reason),
      sort_key: {test.tags.file, test.tags.line}
    }
  end

  defp failure_text(kind, reason, stacktrace) do
    case Footer.blank(reason) do
      %Koans.Blank{message: message} -> message
      nil -> diff(kind, reason, stacktrace)
    end
  end

  defp diff(_kind, %ExUnit.AssertionError{} = error, _stacktrace) do
    case assertion_lines(error) do
      [] ->
        error.message

      lines when error.right == :ex_unit_no_meaningful_value ->
        Enum.join(lines ++ [first_line(error.message)], "\n")

      lines ->
        Enum.join(lines, "\n")
    end
  end

  defp diff(:error, reason, stacktrace),
    do: Exception.message(Exception.normalize(:error, reason, stacktrace))

  defp diff(:throw, reason, _stacktrace), do: "throw: " <> inspect(reason)
  defp diff(_exit, reason, _stacktrace), do: Exception.format_exit(reason)

  defp first_line(message), do: message |> String.split("\n") |> hd()

  defp assertion_lines(error) do
    [
      labelled("code: ", error.expr, &Macro.to_string/1),
      labelled("left:  ", error.left, &pretty/1),
      labelled("right: ", error.right, &pretty/1)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp labelled(_label, :ex_unit_no_meaningful_value, _fun), do: nil
  defp labelled(label, value, fun), do: label <> fun.(value)

  defp pretty(value), do: inspect(value, pretty: true)
end
