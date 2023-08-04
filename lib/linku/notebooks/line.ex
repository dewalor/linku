defmodule Linku.Notebooks.Line do
  use Ecto.Schema
  import Ecto.Changeset

  alias Linku.Repo

  schema "lines" do
    field :status, Ecto.Enum, values: [:started, :completed], default: :started
    field :title, :string
    field :position, :integer

    belongs_to :renku, Linku.Notebooks.Renku
    belongs_to :user, Linku.Accounts.User
    has_many :invitations, Linku.Collaborations.Invitation

    timestamps()
  end

  @doc false
  def changeset(line, attrs) do
    line
    |> Repo.preload(:invitations)
    |> cast(attrs, [:id, :title, :status, :renku_id, :user_id])
    |> cast_assoc(:invitations)
    |> validate_required([:title])
  end
end
