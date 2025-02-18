defmodule Linku.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Linku.Accounts` context.
  """
  alias Linku.Accounts.{User, UserToken}
  alias Linku.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Linku.Accounts.register_user()

    if Map.has_key?(attrs, :confirmed_at) && !is_nil(attrs[:confirmed_at]) do
        {:ok, %{user: confirmed_user}} = Repo.transaction(confirm_user_multi(user))
        confirmed_user
    else
        user
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, ["confirm"]))
  end


  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
