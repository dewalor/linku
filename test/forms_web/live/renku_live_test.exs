defmodule LinkuWeb.RenkuLiveTest do
  use LinkuWeb.ConnCase

  import Phoenix.LiveViewTest
  import Linku.NotebookFixtures

  @create_attrs %{title: "some title"}
  @update_attrs %{title: "some updated title"}
  @invalid_attrs %{title: nil}

  defp create_renku(_) do
    renku = renku_fixture()
    %{renku: renku}
  end

  describe "Index" do
    setup [:create_renku]

    test "lists all renkus", %{conn: conn, renku: renku} do
      {:ok, _index_live, html} = live(conn, ~p"/renkus")

      assert html =~ "Listing Renkus"
      assert html =~ renku.title
    end

    test "saves new renku", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/renkus")

      assert index_live |> element("a", "New Renku") |> render_click() =~
               "New Renku"

      assert_patch(index_live, ~p"/renkus/new")

      assert index_live
             |> form("#renku-form", renku: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#renku-form", renku: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/renkus")

      html = render(index_live)
      assert html =~ "Renku created successfully"
      assert html =~ "some title"
    end

    test "updates renku in listing", %{conn: conn, renku: renku} do
      {:ok, index_live, _html} = live(conn, ~p"/renkus")

      assert index_live |> element("#renkus-#{renku.id} a", "Edit") |> render_click() =~
               "Edit Renku"

      assert_patch(index_live, ~p"/renkus/#{renku}/edit")

      assert index_live
             |> form("#renku-form", renku: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#renku-form", renku: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/renkus")

      html = render(index_live)
      assert html =~ "Renku updated successfully"
      assert html =~ "some updated title"
    end

    test "deletes renku in listing", %{conn: conn, renku: renku} do
      {:ok, index_live, _html} = live(conn, ~p"/renkus")

      assert index_live |> element("#renkus-#{renku.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#renkus-#{renku.id}")
    end
  end

  describe "Show" do
    setup [:create_renku]

    test "displays renku", %{conn: conn, renku: renku} do
      {:ok, _show_live, html} = live(conn, ~p"/renkus/#{renku}")

      assert html =~ "Show Renku"
      assert html =~ renku.title
    end

    test "updates renku within modal", %{conn: conn, renku: renku} do
      {:ok, show_live, _html} = live(conn, ~p"/renkus/#{renku}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Renku"

      assert_patch(show_live, ~p"/renkus/#{renku}/show/edit")

      assert show_live
             |> form("#renku-form", renku: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#renku-form", renku: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/renkus/#{renku}")

      html = render(show_live)
      assert html =~ "Renku updated successfully"
      assert html =~ "some updated title"
    end
  end
end
