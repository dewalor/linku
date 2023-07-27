defmodule Linku.CollaborationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Linku.Collaborations` context.
  """

  @doc """
  Generate a invitation.
  """
  def invitation_fixture(attrs \\ %{}) do
    {:ok, invitation} =
      attrs
      |> Enum.into(%{

      })
      |> Linku.Collaborations.create_invitation()

    invitation
  end
end
