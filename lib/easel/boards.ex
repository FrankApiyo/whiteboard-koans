defmodule Easel.Boards do
  import Ecto.Query

  alias Easel.Boards.{Board, Shape}
  alias Easel.Repo

  def get_board_by_slug!(slug), do: Repo.get_by!(Board, slug: slug)

  def create_board(attrs) do
    %Board{slug: generate_slug()}
    |> Board.changeset(attrs)
    |> Repo.insert()
  end

  def generate_slug do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  def list_boards(slugs) do
    Repo.all(from b in Board, where: b.slug in ^slugs, order_by: b.slug)
  end

  def load_shapes(%Board{id: board_id}) do
    from(s in Shape, where: s.board_id == ^board_id, order_by: s.z)
    |> Repo.all()
    |> Enum.map(&to_map/1)
  end

  def save_shapes(%Board{id: board_id}, shapes) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    rows = Enum.map(shapes, &to_row(&1, board_id, now))

    Repo.transaction(fn ->
      Repo.delete_all(from s in Shape, where: s.board_id == ^board_id)
      rows |> Enum.chunk_every(500) |> Enum.each(&Repo.insert_all(Shape, &1))
    end)
  end

  def subscribe(slug), do: Phoenix.PubSub.subscribe(Easel.PubSub, topic(slug))

  def broadcast_op(slug, message),
    do: Phoenix.PubSub.broadcast(Easel.PubSub, topic(slug), message)

  defp topic(slug), do: "board:#{slug}"

  defp to_row(shape, board_id, now) do
    %{
      board_id: board_id,
      client_id: shape.id,
      kind: shape.kind,
      color: shape.color,
      z: shape.z,
      data: Map.drop(shape, [:id, :kind, :color, :z]),
      inserted_at: now,
      updated_at: now
    }
  end

  defp to_map(%Shape{} = row) do
    data = Map.new(row.data, fn {key, value} -> {String.to_existing_atom(key), value} end)

    Map.merge(data, %{id: row.client_id, kind: row.kind, color: row.color, z: row.z})
  end
end
