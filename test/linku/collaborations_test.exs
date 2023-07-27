defmodule Linku.CollaborationsTest do
  use Linku.DataCase

  alias Linku.Collaborations

  describe "invitations" do
    alias Linku.Collaborations.Invitation

    import Linku.CollaborationsFixtures

    @invalid_attrs %{}

    test "list_invitations/0 returns all invitations" do
      invitation = invitation_fixture()
      assert Collaborations.list_invitations() == [invitation]
    end

    test "get_invitation!/1 returns the invitation with given id" do
      invitation = invitation_fixture()
      assert Collaborations.get_invitation!(invitation.id) == invitation
    end

    test "create_invitation/1 with valid data creates a invitation" do
      valid_attrs = %{}

      assert {:ok, %Invitation{} = invitation} = Collaborations.create_invitation(valid_attrs)
    end

    test "create_invitation/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Collaborations.create_invitation(@invalid_attrs)
    end

    test "update_invitation/2 with valid data updates the invitation" do
      invitation = invitation_fixture()
      update_attrs = %{}

      assert {:ok, %Invitation{} = invitation} = Collaborations.update_invitation(invitation, update_attrs)
    end

    test "update_invitation/2 with invalid data returns error changeset" do
      invitation = invitation_fixture()
      assert {:error, %Ecto.Changeset{}} = Collaborations.update_invitation(invitation, @invalid_attrs)
      assert invitation == Collaborations.get_invitation!(invitation.id)
    end

    test "delete_invitation/1 deletes the invitation" do
      invitation = invitation_fixture()
      assert {:ok, %Invitation{}} = Collaborations.delete_invitation(invitation)
      assert_raise Ecto.NoResultsError, fn -> Collaborations.get_invitation!(invitation.id) end
    end

    test "change_invitation/1 returns a invitation changeset" do
      invitation = invitation_fixture()
      assert %Ecto.Changeset{} = Collaborations.change_invitation(invitation)
    end
  end
end
