defmodule Linku.NotebookTest do
  use Linku.DataCase

  alias Linku.Notebooks

  describe "renkus" do
    alias Linku.Notebooks.Renku

    import Linku.NotebookFixtures

    @invalid_attrs %{title: nil}

    test "list_renkus/0 returns all renkus" do
      renku = renku_fixture()
      assert Notebooks.list_renkus() == [renku]
    end

    test "get_renku!/1 returns the renku with given id" do
      renku = renku_fixture()
      assert Notebooks.get_renku!(renku.id) == renku
    end

    test "create_renku/1 with valid data creates a renku" do
      valid_attrs = %{title: "some title"}

      assert {:ok, %Renku{} = renku} = Notebooks.create_renku(valid_attrs)
      assert renku.title == "some title"
    end

    test "create_renku/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Notebooks.create_renku(@invalid_attrs)
    end

    test "update_renku/2 with valid data updates the renku" do
      renku = renku_fixture()
      update_attrs = %{title: "some updated title"}

      assert {:ok, %Renku{} = renku} = Notebooks.update_renku(renku, update_attrs)
      assert renku.title == "some updated title"
    end

    test "update_renku/2 with invalid data returns error changeset" do
      renku = renku_fixture()
      assert {:error, %Ecto.Changeset{}} = Notebooks.update_renku(renku, @invalid_attrs)
      assert renku == Notebooks.get_renku!(renku.id)
    end

    test "delete_renku/1 deletes the renku" do
      renku = renku_fixture()
      assert {:ok, %Renku{}} = Notebooks.delete_renku(renku)
      assert_raise Ecto.NoResultsError, fn -> Notebooks.get_renku!(renku.id) end
    end

    test "change_renku/1 returns a renku changeset" do
      renku = renku_fixture()
      assert %Ecto.Changeset{} = Notebooks.change_renku(renku)
    end
  end
end
