defmodule LinkuWeb.InvitationLive.Index do
  use LinkuWeb, :live_view

  alias Linku.Collaborations
  alias Linku.Collaborations.Invitation

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :invitations, Collaborations.list_invitations())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Invitation")
    |> assign(:invitation, Collaborations.get_invitation!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Invitation")
    |> assign(:invitation, %Invitation{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Invitations")
    |> assign(:invitation, nil)
  end

  @impl true
  def handle_info({LinkuWeb.InvitationLive.FormComponent, {:saved, invitation}}, socket) do
    {:noreply, stream_insert(socket, :invitations, invitation)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    invitation = Collaborations.get_invitation!(id)
    {:ok, _} = Collaborations.delete_invitation(invitation)

    {:noreply, stream_delete(socket, :invitations, invitation)}
  end
end
