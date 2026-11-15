defmodule Koans.Gen.Backup do
  @moduledoc false

  @dir ".koans/last-reset"

  def dir, do: @dir

  @doc """
  Copies the files at `rels` under `root` into the backup directory, replacing
  whatever an earlier reset left there. A file that does not exist yet is skipped.
  """
  def save(_root, []), do: :ok

  def save(root, rels) do
    backup = Path.join(root, @dir)
    File.rm_rf!(backup)

    for rel <- rels, source = Path.join(root, rel), File.regular?(source) do
      target = Path.join(backup, rel)
      File.mkdir_p!(Path.dirname(target))
      File.cp!(source, target)
    end

    :ok
  end

  def notice do
    "The files as they were before are in #{@dir}/ until the next reset."
  end
end
