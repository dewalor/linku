alias Linku.{Accounts, Notebooks, Scope, Collaborations}

  Accounts.register_user(%{
   email: "ira@example.com",
   password: "nosecreto123"
  })

  Accounts.register_user(%{
    email: "wailee@example.com",
    password: "nosecreto123"
  })

  {:ok, user_1} =
    Accounts.register_user(%{
      email: "iugen@example.com",
      password: "nosecreto123"
    })

  {:ok, user_2} =
    Accounts.register_user(%{
     email: "basho@example.com",
     password: "nosecreto123"
    })

  scope_3 = Scope.for_user(user_1)
  scope_4 = Scope.for_user(user_2)

# Untitled -- Moonlight
moonlight_lines = [
  "By moonlight",
  "my poor mother at work",
  "beside the window",
  "She would hide fingers",
  "stained with indigo"
]

{:ok, moonlight_renku} = Notebooks.create_renku(scope_3, %{title: "Untitled by Iugen and Bashoo", max_lines: Kernel.length(moonlight_lines), published_at: DateTime.utc_now()})

moonlight_lines
|> Enum.with_index()
|> Enum.map(fn {title, i} ->
  cond do
   i in 0..2 ->
     {:ok, line} = Notebooks.create_line(scope_3,  moonlight_renku, %{title: title})
     #Iugen authors the first three lines and invites bashoo to author the next line(s)
     if i < 2 do
      Collaborations.create_invitation(%{line_id: line.id, invitee_email: user_1.email})
     else
      Collaborations.create_invitation(%{line_id: line.id, invitee_email: user_2.email})
     end
   true ->
     {:ok, line} = Notebooks.create_line(scope_4, moonlight_renku, %{title: title})
     #if this is not the last line, send themselves an invitation to write the next line
     if i < Kernel.length(moonlight_lines)-1 do
       Collaborations.create_invitation(%{line_id: line.id, invitee_email: user_2.email})
     end
  end
end)
