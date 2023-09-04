alias Linku.{Accounts, Notebooks, Scope, Collaborations}

{:ok, user} =
  Accounts.register_user(%{
    email: "george@example.com",
    password: "contrasena123"
  })

{:ok, user_2} =
  Accounts.register_user(%{
   email: "ira@example.com",
   password: "contrasena123"
  })

scope = Scope.for_user(user)
scope_2 = Scope.for_user(user_2)

# Someone To Watch Over Me
someone_lines = [
  "There's a saying old says that love is blind",
  "Still we're often told 'seek and ye shall find'",
  "So I'm going to seek a certain girl I've had in mind",
  "Looking everywhere, haven't found her yet",
  "She's the big affair I cannot forget",
  "Only girl I ever think of with regret",
  "I'd like to add her initials to my monogram",
  "Tell me where's the shepherd for this lost lamb",
  "There's a somebody I'm longing to see",
  "I hope that she turns out to be",
  "Someone to watch over me",
  "I'm a little lamb who's lost in a wood",
  "I know I could always be good",
  "To one who'll watch over me",
  "Although I may not be the man",
  "some girls think of",
  "As handsome to my heart",
  "She carries the key",
  "Won't you tell her please to put on some speed",
  "Follow my lead, oh how I need",
  "Someone to watch over me",
  "Someone to watch over me"
]


{:ok, someone_song} = Notebooks.create_renku(scope, %{title: "Someone To Watch Over Me", max_lines: Kernel.length(someone_lines), published_at: DateTime.utc_now()})

someone_lines
|> Enum.with_index()
|> Enum.map(fn {title, i} ->
     case rem(i, 2) do
      0 ->
        {:ok, line} = Notebooks.create_line(scope, someone_song, %{title: title})
        #if this is not the last line, invite another user to write the next line
        if i < Kernel.length(someone_lines)-1 do
          Collaborations.create_invitation(%{line_id: line.id, invitee_email: user_2.email})
        end
      1 ->
        {:ok, line} = Notebooks.create_line(scope_2, someone_song, %{title: title})
        #if this is not the last line, invite another user to write the next line
        if i < Kernel.length(someone_lines)-1 do
          Collaborations.create_invitation(%{line_id: line.id, invitee_email: user.email})
        end
     end
  end)

  {:ok, user_3} =
    Accounts.register_user(%{
      email: "iugen@example.com",
      password: "contrasena123"
    })

  {:ok, user_4} =
    Accounts.register_user(%{
     email: "basho@example.com",
     password: "contrasena123"
    })

  scope_3 = Scope.for_user(user_3)
  scope_4 = Scope.for_user(user_4)

# Untitled -- Moonlight
moonlight_lines = [
  "By moonlight",
  "my poor mother at work",
  "beside the window",
  "She would hide fingers",
  "stained with indigo"
]

{:ok, moonlight_renku} = Notebooks.create_renku(scope_3, %{title: "Untitled", max_lines: Kernel.length(moonlight_lines), published_at: DateTime.utc_now()})

moonlight_lines
|> Enum.with_index()
|> Enum.map(fn {title, i} ->
  cond do
   i in 0..2 ->
     {:ok, line} = Notebooks.create_line(scope_3,  moonlight_renku, %{title: title})
     #Iugen authors the first three lines and invites bashoo to author the next line(s)
     if i < 2 do
      Collaborations.create_invitation(%{line_id: line.id, invitee_email: user_3.email})
     else
      Collaborations.create_invitation(%{line_id: line.id, invitee_email: user_4.email})
     end
   true ->
     {:ok, line} = Notebooks.create_line(scope_4, moonlight_renku, %{title: title})
     #if this is not the last line, send themselves an invitation to write the next line
     if i < Kernel.length(moonlight_lines)-1 do
       Collaborations.create_invitation(%{line_id: line.id, invitee_email: user_4.email})
     end
  end
end)
