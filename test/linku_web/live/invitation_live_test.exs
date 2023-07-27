defmodule LinkuWeb.InvitationLiveTest do
  use LinkuWeb.ConnCase

  import Phoenix.LiveViewTest
  import Linku.CollaborationsFixtures

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  defp create_invitation(_) do
    invitation = invitation_fixture()
    %{invitation: invitation}
  end

  describe "Index" do
    setup [:create_invitation]

    test "lists all invitations", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/invitations")

      assert html =~ "Listing Invitations"
    end

    test "saves new invitation", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/invitations")

      assert index_live |> element("a", "New Invitation") |> render_click() =~
               "New Invitation"

      assert_patch(index_live, ~p"/invitations/new")

      assert index_live
             |> form("#invitation-form", invitation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#invitation-form", invitation: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/invitations")

      html = render(index_live)
      assert html =~ "Invitation created successfully"
    end

    test "updates invitation in listing", %{conn: conn, invitation: invitation} do
      {:ok, index_live, _html} = live(conn, ~p"/invitations")

      assert index_live |> element("#invitations-#{invitation.id} a", "Edit") |> render_click() =~
               "Edit Invitation"

      assert_patch(index_live, ~p"/invitations/#{invitation}/edit")

      assert index_live
             |> form("#invitation-form", invitation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#invitation-form", invitation: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/invitations")

      html = render(index_live)
      assert html =~ "Invitation updated successfully"
    end

    test "deletes invitation in listing", %{conn: conn, invitation: invitation} do
      {:ok, index_live, _html} = live(conn, ~p"/invitations")

      assert index_live |> element("#invitations-#{invitation.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#invitations-#{invitation.id}")
    end
  end

  describe "Show" do
    setup [:create_invitation]

    test "displays invitation", %{conn: conn, invitation: invitation} do
      {:ok, _show_live, html} = live(conn, ~p"/invitations/#{invitation}")

      assert html =~ "Show Invitation"
    end

    test "updates invitation within modal", %{conn: conn, invitation: invitation} do
      {:ok, show_live, _html} = live(conn, ~p"/invitations/#{invitation}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Invitation"

      assert_patch(show_live, ~p"/invitations/#{invitation}/show/edit")

      assert show_live
             |> form("#invitation-form", invitation: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#invitation-form", invitation: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/invitations/#{invitation}")

      html = render(show_live)
      assert html =~ "Invitation updated successfully"
    end
  end
end
