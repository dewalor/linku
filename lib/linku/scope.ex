defmodule Linku.Scope do
  @moduledoc """
  Defines the scope the caller to be used throughout the app.

  The %Scope{} allows public interfaces to receive information
  about the caller, such as if the call is initiated from an end-user,
  and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope. It is useful
  for logging as well as for scoping pubsub subscriptions and broadcasts when a
  caller subscribes to an interface or performs a particular action.

  Feel free to extend the fields on this struct to fit the needs of the
  growing application requirements.
  """
  defstruct current_user: nil, current_user_id: nil

  def for_user(nil) do
    %__MODULE__{current_user: nil, current_user_id: nil}
  end

  def for_user(%Linku.Accounts.User{} = user) do
    %__MODULE__{current_user: user, current_user_id: user.id}
  end
end
