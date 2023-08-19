defmodule Linku.Collaborations.InvitationNotifier do
  import Swoosh.Email

  alias Linku.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Forms", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_invitation(invitee_email, sender_email, invitation_key) do
    url = "#{LinkuWeb.Endpoint.url()}/invitations/#{invitation_key}"

    deliver(invitee_email, sender_email, """

    ==============================

      Hi #{invitee_email},

      Check this out.  Your friend #{sender_email} sent you an invitation to write a renku, a collaborative poem.

      Visit the URL below:
      #{url}

      Hint: If you don't have an account with Linku, create one now.

    ==============================

    """)
  end
end
