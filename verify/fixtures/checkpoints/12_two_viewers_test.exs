defmodule Verify.Checkpoints.TwoViewersTest do
  use EaselWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Easel.BoardsFixtures

  @id "6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab"
  @rect %{
    "id" => @id,
    "kind" => "rect",
    "color" => "#e03131",
    "x" => 10,
    "y" => 20,
    "w" => 30,
    "h" => 40
  }

  test "an add in one view is pushed to another, and both people are listed", %{conn: conn} do
    board = board_fixture()
    path = ~p"/b/#{board.slug}"
    {:ok, ada, _html} = live(with_identity(conn, "Ada"), path)
    {:ok, lin, _html} = live(with_identity(build_conn(), "Lin"), path)

    render_hook(ada, "shape:add", @rect)

    assert_push_event lin, "shape:added", %{id: @id, x: 10}
    assert eventually(fn -> names(ada) == ["Ada", "Lin"] end)
    assert names(lin) == ["Ada", "Lin"]
  end

  defp names(view),
    do: view |> board_props() |> Map.fetch!("people") |> Enum.map(& &1["name"]) |> Enum.sort()

  defp eventually(check, attempts \\ 100) do
    cond do
      check.() -> true
      attempts <= 1 -> false
      true -> Process.sleep(10) && eventually(check, attempts - 1)
    end
  end
end
