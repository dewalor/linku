defmodule Linku.TodosFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Linku.Todos` context.
  """

  @doc """
  Generate a renku.
  """
  def renku_fixture(attrs \\ %{}) do
    {:ok, renku} =
      attrs
      |> Enum.into(%{
        title: "some title"
      })
      |> Linku.Todos.create_renku()

    renku
  end
end
