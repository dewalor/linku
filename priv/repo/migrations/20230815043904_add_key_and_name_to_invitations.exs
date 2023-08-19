defmodule Linku.Repo.Migrations.AddKeyAndNameToInvitations do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE invitations ADD COLUMN key TEXT;"
    execute "ALTER TABLE invitations ADD COLUMN invitee_name TEXT;"

    #backfill
    execute "update invitations set key = LOWER(SUBSTRING(MD5(''||NOW()::TEXT||RANDOM()::TEXT) FOR 8)) where key is NULL;"

    execute "CREATE UNIQUE INDEX ON invitations (lower(key));"

    execute "ALTER TABLE invitations ALTER COLUMN key SET NOT NULL;"
  end

  def down do
    execute "ALTER TABLE invitations DROP COLUMN key;"
    execute "ALTER TABLE invitations DROP COLUMN invitee_name;"
  end
end
