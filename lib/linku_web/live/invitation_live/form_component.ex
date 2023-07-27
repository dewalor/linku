defmodule LinkuWeb.InvitationLive.FormComponent do
  use LinkuWeb, :live_component

  alias Linku.Collaborations

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage invitation records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="invitation-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >

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
         |> push_patch(to: socket.assigns.patch)}

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
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end