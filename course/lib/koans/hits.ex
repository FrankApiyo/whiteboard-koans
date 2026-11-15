defmodule Koans.Hits do
  @table :koans_hits

  # Without the table (e.g. `iex -S mix`) every call is a no-op, so a code blank still raises its own message.
  def start do
    if missing?(), do: :ets.new(@table, [:named_table, :public, :set])
    :ok
  end

  def clear do
    unless missing?(), do: :ets.delete_all_objects(@table)
    :ok
  end

  def record(file, line, tag, mfa) do
    unless missing?(), do: :ets.insert(@table, {:last, file, line, tag, mfa})
    :ok
  end

  def record_soft(file, line, tag, mfa) do
    unless missing?(),
      do:
        :ets.insert(@table, {{:soft, System.unique_integer([:monotonic])}, file, line, tag, mfa})

    :ok
  end

  def soft do
    if missing?() do
      []
    else
      @table
      |> :ets.match_object({{:soft, :_}, :_, :_, :_, :_})
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {_key, file, line, tag, mfa} -> {file, line, tag, mfa} end)
    end
  end

  def last do
    case missing?() or :ets.lookup(@table, :last) do
      [{:last, file, line, tag, mfa}] -> {file, line, tag, mfa}
      _ -> nil
    end
  end

  defp missing?, do: :ets.whereis(@table) == :undefined
end
