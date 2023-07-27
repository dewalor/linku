defmodule Linku.Notebook.Renku do
  use Ecto.Schema
  import Ecto.Changeset

  schema "renkus" do
    field :title, :string
    field :position, :integer

    has_many :lines, Linku.Notebook.Line
    belongs_to :user, Linku.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(renku, attrs) do
    renku
    |> cast(attrs, [:title])
    |> validate_required([:title])
  end
end
