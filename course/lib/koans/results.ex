defmodule Koans.Results do
  @files ~w(ex.jsonl ts.jsonl)
  @kind_rank %{"ts" => 0, "ex" => 1}

  def read(dir) do
    paths = Enum.map(@files, &Path.join(dir, &1))

    if Enum.all?(paths, &File.regular?/1) do
      Enum.flat_map(paths, &read_file/1)
    else
      {:error, :missing}
    end
  end

  def earliest(records) do
    records
    |> Enum.reject(&(&1["status"] == "ok"))
    |> Enum.min_by(&sort_key/1, fn -> nil end)
  end

  def footer(records, total) do
    Koans.Footer.render(%{
      passed: Enum.count(records, &(&1["status"] == "ok")),
      total: total,
      ran: length(records),
      failure: records |> earliest() |> failure(),
      scope: :all
    })
  end

  defp read_file(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&JSON.decode!/1)
  end

  defp sort_key(record) do
    {record["chapter"], Map.fetch!(@kind_rank, record["kind"]), record["file"], record["line"]}
  end

  defp failure(nil), do: nil

  defp failure(record) do
    %{
      path: record["file"],
      line: record["at"] || record["line"],
      meditation: record["meditation"] || "",
      diff: record["diff"],
      write: write(record["write"])
    }
  end

  defp write(nil), do: nil

  defp write(%{"path" => path, "line" => line, "where" => where}),
    do: %{path: path, line: line, where: where}
end
