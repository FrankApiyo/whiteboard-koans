defmodule VerifyFailureFormatter do
  use GenServer

  def init(_opts), do: {:ok, nil}

  def handle_cast({:test_finished, %ExUnit.Test{state: {:excluded, _}}}, config) do
    {:noreply, config}
  end

  def handle_cast({:test_finished, %ExUnit.Test{name: name, state: state, tags: tags}}, config) do
    IO.puts(describe(name, state, tags))
    {:noreply, config}
  end

  def handle_cast(_event, config), do: {:noreply, config}

  defp describe(name, nil, tags),
    do: "RESULT #{name} passed meditation=#{inspect(tags[:meditation])}"

  defp describe(
         name,
         {:failed, [{{:EXIT, _pid}, {%Koans.Blank{} = blank, _}, _stack} | _]},
         _tags
       ) do
    "RESULT #{name} failed kind=:linked_exit error=Koans.Blank line=#{blank.line} file=#{Path.basename(blank.file)}"
  end

  defp describe(name, {:failed, [{kind, reason, stack} | _]}, _tags) do
    "RESULT #{name} failed kind=#{inspect(kind)} error=#{error_name(reason)} line=#{line(reason, stack)}"
  end

  defp describe(name, other, _tags), do: "RESULT #{name} #{inspect(other)}"

  defp error_name(%{__struct__: module}), do: inspect(module)
  defp error_name(other), do: "non_exception:#{inspect(other)}"

  defp line(%Koans.Blank{line: line}, _stack), do: line

  defp line(_reason, stack) do
    Enum.find_value(stack, fn {_m, _f, _a, location} ->
      file = to_string(location[:file])
      if String.ends_with?(file, "_test.exs"), do: location[:line]
    end)
  end
end
