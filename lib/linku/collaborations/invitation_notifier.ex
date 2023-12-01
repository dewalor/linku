defmodule Linku.Collaborations.InvitationNotifier do
  import Swoosh.Email

  alias Linku.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Linku Renku", "dewalor@proton.me"})
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

      The link will take you to the Linku site, where you may:
      1. login or create an account if you don't have one
              or
      2. enter your email and receive a Magic Link to login without creating a password.

      By clicking on the link below, you confirm:
      1. you are human
             and
      2. you give Linku permission to send you e-mails.

      #{url}

    ==============================

    """)
  end
end
