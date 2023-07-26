defmodule LinkuWeb.RenkuLive.FormComponent do
  use LinkuWeb, :live_component

  alias Linku.Todos

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header><%= @title %></.header>
      <.simple_form
        for={@form}
        id="renku-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4 mb-6">
          <.input field={@form[:title]} type="text" />
        </div>
        <:actions>
          <.button phx-disable-with="Saving...">
            Save Renku
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{renku: renku} = assigns, socket) do
    changeset = Todos.change_renku(renku)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"renku" => renku_params}, socket) do
    changeset =
      socket.assigns.renku
      |> Todos.change_renku(renku_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"renku" => renku_params}, socket) do
    save_renku(socket, socket.assigns.action, renku_params)
  end

  defp save_renku(socket, :edit_renku, renku_params) do
    case Todos.update_renku(socket.assigns.scope, socket.assigns.renku, renku_params) do
      {:ok, _renku} ->
        {:noreply,
         socket
         |> put_flash(:info, "Renku updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_renku(socket, :new_renku, renku_params) do
    case Todos.create_renku(socket.assigns.scope, renku_params) do
      {:ok, _renku} ->
        {:noreply,
         socket
         |> put_flash(:info, "Renku created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end
end
