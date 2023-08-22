defmodule Linku.Notebooks.Renku do
  use Ecto.Schema
  import Ecto.Changeset

  schema "renkus" do
    field :title, :string
    field :position, :integer
    field :max_lines, :integer

    has_many :lines, Linku.Notebooks.Line
    belongs_to :user, Linku.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(renku, attrs) do
    renku
    |> cast(attrs, [:title, :max_lines])
    |> validate_required([:title, :max_lines])
  end
end
