defmodule Linku.Collaborations.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invitations" do
    field :invitee_email, :string
    field :accepted_at, :utc_datetime_usec

    belongs_to :line, Linku.Notebooks.Line
    timestamps()
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:id, :invitee_email, :accepted_at, :line_id])
    |> validate_required([:invitee_email, :line_id])
  end
end
