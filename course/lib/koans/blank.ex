defmodule Koans.Blank do
  defexception [:message, :file, :line, :tag, :mfa]

  @value_message "Replace __ with the value that makes this true."
  @code_message "Replace __() with the code the meditation describes."

  def code_message, do: @code_message

  @impl true
  def message(%__MODULE__{message: message, file: file, line: line, mfa: {mod, fun, arity}}) do
    where = "#{Path.relative_to_cwd(file)}:#{line}  (#{inspect(mod)}.#{fun}/#{arity})"
    "#{message}\nWrite:          #{where}"
  end

  def message(%__MODULE__{message: message}), do: message

  def value!(file, line) do
    opaque_raise(%__MODULE__{message: @value_message, file: file, line: line})
  end

  def code!(file, line, tag, mfa) do
    Koans.Hits.record(file, line, tag, mfa)

    opaque_raise(%__MODULE__{
      message: @code_message,
      file: file,
      line: line,
      tag: tag,
      mfa: mfa
    })
  end

  # apply/3 keeps the type checker from flagging expressions that always raise.
  defp opaque_raise(exception), do: apply(:erlang, :error, [exception])
end
