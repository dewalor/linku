defmodule Linku.Repo.Migrations.CreateActivityLogEntries do
  use Ecto.Migration

  def change do
    create table(:activity_log_entries) do
      add :action, :string, null: false
      add :performer_text, :string, null: false
      add :subject_text, :string, null: false
      add :before_text, :string
      add :after_text, :string
      add :meta, :jsonb, null: false
      add :line_id, references(:lines, on_delete: :nilify_all), null: true
      add :renku_id, references(:renkus, on_delete: :nilify_all), null: true
      add :user_id, references(:users, on_delete: :nilify_all), null: true

      timestamps()
    end

    create index(:activity_log_entries, [:line_id])
    create index(:activity_log_entries, [:renku_id])
    create index(:activity_log_entries, [:user_id])
  end
end
