defmodule Linku.Repo.Migrations.AddPublishedAtToRenkus do
  use Ecto.Migration

  def change do
    alter table(:renkus) do
      add :published_at, :utc_datetime_usec
    end
  end
end
