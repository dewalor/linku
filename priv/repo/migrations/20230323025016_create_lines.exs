defmodule Linku.Repo.Migrations.CreateLines do
  use Ecto.Migration

  def change do
    create table(:lines) do
      add :title, :string
      add :status, :string
      add :position, :integer, null: false
      add :renku_id, references(:renkus, on_delete: :nothing)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:lines, [:renku_id])
  end
end
