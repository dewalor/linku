defmodule LinkuWeb.InvitationLive.FormComponent do
  use LinkuWeb, :live_component

  alias Linku.Collaborations
  alias Linku.Collaborations.Invitation

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>

      <.simple_form
        for={@form}
        id="invitation-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
      <.input field={@form[:line_id]} type="hidden" value={@form.data.line_id}/>
      <.input
        field={@form[:invitee_email]}
        type="text"
        placeholder="Invitee Email"
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save Invitation</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{invitation: invitation} = assigns, socket) do
    changeset = Collaborations.change_invitation(invitation)

    {:ok,
     socket
     |> assign(assigns)
  #   |> assign_invitation()
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"invitation" => invitation_params}, socket) do
    changeset =
      socket.assigns.invitation
      |> Collaborations.change_invitation(invitation_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"invitation" => invitation_params}, socket) do
    save_invitation(socket, socket.assigns.action, invitation_params)
  end

  defp save_invitation(socket, :edit, invitation_params) do
    case Collaborations.update_invitation(socket.assigns.invitation, invitation_params) do
      {:ok, invitation} ->
        notify_parent({:saved, invitation})

        {:noreply,
         socket
         |> put_flash(:info, "Invitation updated successfully")
         |> push_navigate(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_invitation(socket, :new, invitation_params) do
    case Collaborations.create_invitation(invitation_params) do
      {:ok, invitation} ->
        notify_parent({:saved, invitation})

        {:noreply,
         socket
         |> put_flash(:info, "Invitation created successfully")
         |> push_navigate(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_invitation(socket) do
    assign(socket, :invitation, %Invitation{})
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
