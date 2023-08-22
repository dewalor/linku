defmodule Linku.Notebooks.Renku do
  use Ecto.Schema
  import Ecto.Changeset

  schema "renkus" do
    field :title, :string
    field :position, :integer
    field :max_lines, :integer
    field :published_at, :utc_datetime_usec

    has_many :lines, Linku.Notebooks.Line
    belongs_to :user, Linku.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(renku, attrs) do
    renku
    |> cast(attrs, [:title, :max_lines, :published_at])
    |> validate_required([:title, :max_lines])
  end

  def publish_changeset(renku) do
    now = DateTime.utc_now()
    change(renku, published_at: now)
  end
end
