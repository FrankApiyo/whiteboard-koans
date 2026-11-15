defmodule Easel.Boards do
  # >>> course
  import Koans, only: [__: 1, __: 2], warn: false
  # <<< course
  import Ecto.Query, warn: false

  alias Easel.Boards.{Board, Shape}, warn: false
  alias Easel.Repo, warn: false

  def get_board_by_slug!(slug), do: Repo.get_by!(Board, slug: slug)

  def get_board_by_slug(slug), do: Repo.get_by(Board, slug: slug)

  def create_board(attrs) do
    # >>> 07
    __("07: insert a board with a fresh slug")
    # <<< 07
  end

  def generate_slug do
    # >>> 07
    __("07: 16 random bytes, URL-safe")
    # <<< 07
  end

  def list_boards(slugs) do
    # >>> 07
    __("07: the boards with these slugs")
    # <<< 07
  end

  def load_shapes(%Board{id: board_id}) do
    # >>> 07
    __("07: the board's rows, lowest z first")
    # <<< 07
    |> Enum.map(&to_map/1)
  end

  # SQLite binds at most 32_766 variables per statement, and each row binds six.
  @rows_per_insert 1_000

  def save_shapes(%Board{id: board_id}, shapes) do
    rows = Enum.map(shapes, &to_row(&1, board_id))

    Repo.transact(fn ->
      # >>> 07
      __("07: delete the board's old rows")
      # <<< 07
      rows |> Enum.chunk_every(@rows_per_insert) |> Enum.each(&Repo.insert_all(Shape, &1))
      {:ok, length(rows)}
    end)
  end

  def subscribe(slug), do: Phoenix.PubSub.subscribe(Easel.PubSub, topic(slug))

  def broadcast_op(slug, message),
    do: Phoenix.PubSub.broadcast(Easel.PubSub, topic(slug), message)

  def topic(slug), do: "board:#{slug}"

  defp to_row(shape, board_id) do
    %{
      board_id: board_id,
      client_id: shape.id,
      kind: shape.kind,
      color: shape.color,
      z: shape.z,
      data: Map.drop(shape, [:id, :kind, :color, :z])
    }
  end

  defp to_map(%Shape{} = row) do
    data = Map.new(row.data, fn {key, value} -> {String.to_existing_atom(key), value} end)

    Map.merge(data, %{id: row.client_id, kind: row.kind, color: row.color, z: row.z})
  end
end
