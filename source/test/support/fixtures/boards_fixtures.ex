defmodule Easel.BoardsFixtures do
  alias Easel.Boards.{Board, Shape}
  alias Easel.Repo

  def board_fixture(attrs \\ %{}) do
    %Board{title: "Sketch", slug: unique_slug()}
    |> struct!(Map.new(attrs))
    |> Repo.insert!()
  end

  def shape_fixture(%Board{id: board_id}, attrs \\ %{}) do
    %Shape{
      board_id: board_id,
      client_id: Ecto.UUID.generate(),
      kind: "rect",
      color: hd(Easel.Palette.colors()),
      z: 0,
      data: %{x: 10, y: 10, w: 100, h: 50}
    }
    |> struct!(Map.new(attrs))
    |> Repo.insert!()
  end

  defp unique_slug, do: "board-#{System.unique_integer([:positive])}"
end
