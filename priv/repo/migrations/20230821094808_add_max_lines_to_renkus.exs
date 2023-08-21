defmodule Linku.Repo.Migrations.AddMaxLinesToRenkus do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE renkus ADD COLUMN max_lines INTEGER;"

    #backfill
    execute "UPDATE renkus SET max_lines = 31 where max_lines IS NULL;"

    execute "ALTER TABLE renkus ALTER COLUMN max_lines SET NOT NULL;"
  end

  def down do
    execute "ALTER TABLE renkus DROP COLUMN max_lines;"
  end
end
