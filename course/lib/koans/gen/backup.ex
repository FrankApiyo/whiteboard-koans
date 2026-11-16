defmodule Koans.Gen.Backup do
  @moduledoc false

  @dirs %{reset: ".koans/last-reset", gen: ".koans/last-gen"}

  @doc """
  Copies the files at `rels` under `root` into the backup directory for `kind`
  (`:reset` or `:gen`), replacing whatever an earlier run of the same kind left
  there. A file that does not exist yet is skipped.
  """
  def save(_root, [], _kind), do: :ok

  def save(root, rels, kind) do
    backup = Path.join(root, Map.fetch!(@dirs, kind))
    File.rm_rf!(backup)

    for rel <- rels, source = Path.join(root, rel), File.regular?(source) do
      target = Path.join(backup, rel)
      File.mkdir_p!(Path.dirname(target))
      File.cp!(source, target)
    end

    :ok
  end

  def notice(:reset) do
    "The files as they were before are in #{@dirs.reset}/ until the next reset."
  end

  def notice(:gen) do
    "The files as they were before are in #{@dirs.gen}/ until the next koans.gen."
  end
end
