defmodule Easel.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Easel.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Easel.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Easel.DataCase
    end
  end

  setup tags do
    Easel.DataCase.setup_sandbox(tags)
    on_exit(&Easel.DataCase.stop_boards/0)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Easel.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Stops every board server, so each one flushes its pending save.

  Register it with `on_exit` after `setup_sandbox/1`: callbacks run in reverse
  order, so the boards stop while the sandbox owner can still save for them.
  """
  def stop_boards do
    for {_, pid, _, _} <- DynamicSupervisor.which_children(Easel.Boards.BoardSupervisor),
        is_pid(pid) do
      DynamicSupervisor.terminate_child(Easel.Boards.BoardSupervisor, pid)
    end

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
