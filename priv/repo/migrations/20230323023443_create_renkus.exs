defmodule Linku.Repo.Migrations.CreateRenkus do
  use Ecto.Migration

  def change do
    create table(:renkus) do
      add :title, :string
      add :user_id, references(:users, on_delete: :delete_all)
      add :position, :integer, null: false

      timestamps()
    end
  end
end
