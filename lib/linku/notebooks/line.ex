defmodule Linku.Notebooks.Line do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lines" do
    field :status, Ecto.Enum, values: [:started, :completed], default: :started
    field :title, :string
    field :position, :integer

    belongs_to :renku, Linku.Notebooks.Renku
    belongs_to :user, Linku.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(line, attrs) do
    line
    |> cast(attrs, [:id, :title, :status])
    |> validate_required([:title])
  end
end
