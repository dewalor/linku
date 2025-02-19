defmodule LinkuWeb.UserSessionController do
  use LinkuWeb, :controller

  alias Linku.Accounts
  alias Linku.Accounts.User
  alias LinkuWeb.UserAuth
  alias Linku.Collaborations

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, %{"_action" => "magic_link"} = params) do
    %{"user" => %{"email" => email}} = params

    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_magic_link(user)
    else
      #if e-mail is associated with at least one invitation, create a user record and send magic link
      with Collaborations.associated_with_invitations?(email),
      {:ok, user} <- Accounts.register_user(%{email: email, password: :crypto.strong_rand_bytes(15)}) do
            Accounts.deliver_magic_link(user)
      end
    end

    # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
    conn
    |> put_flash(:info, "If we find an account for #{email} we'll send a one-time sign-in link")
    |> redirect(to: ~p"/users/log_in")
  end

  def create(conn, %{"token" => token} = _params) do
    case Accounts.get_confirmed_user_by_email_token(token, "magic_link") do
      %User{} = user ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> UserAuth.log_in_user(user)

      _ ->
        conn
        |> put_flash(:error, "That link didn't seem to work. Please try again.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_confirmed_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password or unconfirmed account.")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
