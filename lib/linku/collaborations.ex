defmodule Linku.Collaborations do
  @moduledoc """
  The Collaborations context.
  """

  import Ecto.Query, warn: false
  alias Linku.Repo
  alias Linku.Notebooks.Line
  alias Linku.Collaborations.Invitation

  @doc """
  Returns the list of invitations.

  ## Examples

      iex> list_invitations()
      [%Invitation{}, ...]

  """
  def list_invitations do
    Repo.all(Invitation)
  end

  @doc """
  Gets a single invitation.

  Raises `Ecto.NoResultsError` if the Invitation does not exist.

  ## Examples

      iex> get_invitation!(123)
      %Invitation{}

      iex> get_invitation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_invitation!(id), do: Repo.get!(Invitation, id)

  @doc """
  Whether an email is associated with any invitations.
  """
  def associated_with_invitations?(email) do
    query = from i in Invitation, where: i.invitee_email == ^email
    Repo.exists?(query)
  end

  @doc """
  The email of the invitee with an open invitation to compose a line for the renku, if any.
  There can be at most one open invitation for a renku.
  Returns nil if the last line of the renku is complete and there are no open invitations.
  """
  def current_invitee_email(renku) do
    #the last line of renku won't have any invitations
    query = from i in Invitation, select: i.invitee_email, join: l in Line, on: l.id == i.line_id, where: l.renku_id == ^renku.id and is_nil(i.accepted_at)
    Repo.one(query)
  end

  @doc """
  Creates a invitation.

  ## Examples

      iex> create_invitation(%{field: value})
      {:ok, %Invitation{}}

      iex> create_invitation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_invitation(attrs \\ %{}) do
    %Invitation{ key: generate_random_key() }
    |> Invitation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a invitation.

  ## Examples

      iex> update_invitation(invitation, %{field: new_value})
      {:ok, %Invitation{}}

      iex> update_invitation(invitation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_invitation(%Invitation{} = invitation, attrs) do
    invitation
    |> Invitation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a invitation.

  ## Examples

      iex> delete_invitation(invitation)
      {:ok, %Invitation{}}

      iex> delete_invitation(invitation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_invitation(%Invitation{} = invitation) do
    Repo.delete(invitation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking invitation changes.

  ## Examples

      iex> change_invitation(invitation)
      %Ecto.Changeset{data: %Invitation{}}

  """
  def change_invitation(%Invitation{} = invitation, attrs \\ %{}) do
    case attrs do
      %{"invitee_email" => invitee_email, "line_id" => line_id} -> Invitation.changeset(invitation, %{"invitee_email" => invitee_email, "line_id" => String.to_integer(line_id)})
      _ -> Invitation.changeset(invitation, attrs)
    end

  end

  defp generate_random_key() do
    :crypto.strong_rand_bytes(8)
    |> Base.url_encode64()
    |> String.replace(~r/[-_\=]/, "")
    |> Kernel.binary_part(0, 8)
  end
end
