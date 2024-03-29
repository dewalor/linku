defmodule Linku.Notebooks.RenkuNotifier do
  import Swoosh.Email

  alias Linku.Accounts.User
  alias Linku.Mailer
  alias Linku.Notebooks.Renku

  # TODO: refactor and consolidate
  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Linku Renku", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_renku_completion_notification(%User{} = initiator,  %User{} = invitee, %Renku{} = renku) do
    url = LinkuWeb.Endpoint.url()

    deliver(initiator.email, "",
    """
    ==============================
    Hi #{initiator.email},

    #{invitee.email} has completed the last line of the renku #{renku.title}.  The renku has reached its maximum length and can now be published.

    By clicking the Publish button:
    1. you confirm the poem is original, unpublished work
                and
    2. you give Linku the right to publish the poem

    Upon publication, the rights to the poem will revert to you.

    #{url}

    Linku Renku
    ==============================
    """
    )
  end
end
