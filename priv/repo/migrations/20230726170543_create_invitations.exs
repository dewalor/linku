defmodule Linku.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    create table(:invitations) do
      add :invitee_email, :string
      add :line_id, references(:lines, on_delete: :nothing)

      add :accepted_at, :utc_datetime_usec

      timestamps()
    end

    create index(:invitations, [:invitee_email])
    create index(:invitations, [:line_id])
  end
end
