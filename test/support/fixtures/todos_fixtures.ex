defmodule Linku.TodosFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Linku.Todos` context.
  """

  @doc """
  Generate a list.
  """
  def list_fixture(attrs \\ %{}) do
    {:ok, list} =
      attrs
      |> Enum.into(%{
        title: "some title"
      })
      |> Linku.Todos.create_list()

    list
  end
end
