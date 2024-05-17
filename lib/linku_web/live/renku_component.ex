defmodule LinkuWeb.RenkuComponent do
  use LinkuWeb, :live_component
  import Ecto.Changeset

  alias Linku.Repo
  alias Linku.Events
  alias Linku.Notebooks
  alias Linku.Notebooks.Line
  alias Linku.Collaborations

  def render(assigns) do
    #   <.live_component
    #   if={form[:invitations]}
    #   module={InvitationLive.FormComponent}
    #   invitation={@invitation}
    #   id="invitation-form"
    # />
    ~H"""
    <div>
      <div
        id={"lines-#{@renku.id}"}
        :if={@renku.user_id == assigns.scope.current_user.id || @line_count < @max_lines}
        phx-update="stream"
        phx-hook="Sortable"
        class="grid grid-cols-1 gap-2"
        data-group="lines"
        data-renku_id={@renku.id}
        data-max_lines={@max_lines}
      >
        <div class="space-x-3"
         :if={!@renku.published_at and @line_count == @max_lines}
        >
          Congrats!  This renku has reached its max length and can now be published.
        </div>
        <div
          :for={{id, form} <- @streams.lines}
          id={id}
          data-id={form.data.id}
          data-renku_id={form.data.renku_id}
          class="
          relative flex items-center space-x-3 rounded-lg border border-gray-300 bg-white px-2 shadow-sm
          focus-within:ring-2 focus-within:ring-indigo-500 focus-within:ring-offset-2 hover:border-gray-400
          drag-item:focus-within:ring-0 drag-item:focus-within:ring-offset-0
          drag-ghost:bg-zinc-300 drag-ghost:border-0 drag-ghost:ring-0
          "
        >
          <.simple_form
            for={form}
            phx-change="validate"
            phx-submit="save"
            phx-value-id={form.data.id}
            phx-target={@myself}
            class="min-w-0 flex-1 drag-ghost:opacity-0"
          >

            <div class="flex">
              <div class="flex-auto">
                <input type="hidden" name={form[:status].name} value={form[:status].value} />
                <.input
                  :if={form.data.id || @show_new_line}
                  type="text"
                  field={form[:title]}
                  border={false}
                  placeholder="New line..."
                  phx-mounted={!form.data.id && JS.focus()}
                  phx-keydown={!form.data.id && JS.push("discard", target: @myself)}
                  phx-key="escape"
                  phx-change="save"
                  phx-debounce="2000"
                  phx-blur={form.data.id && JS.dispatch("submit", to: "##{form.id}")}
                  phx-target={@myself}
                />
                <!-- only display the invitation section if current user is the author of the line -->
                  <div class="bg-white"
                   :if={!form.data.id || (form.data.id && assigns.scope.current_user.id == form.data.user_id)}
                  >
                    <.link
                      :if={
                          @display_invitations && (@display_invitation_pencil || form.data.id)
                          && form.data.position < @max_lines - 1
                          && form.data.position == @line_count - 1
                          }
                      patch={~p"/lines/#{form.data.id}/invitations/new"}
                      alt="New invitation">
                      <.icon name="hero-pencil-square" />
                    </.link>
                    <.inputs_for
                      :let={form_invitations}
                      :if={@display_invitations}
                      field={form[:invitations]}>
                      <.input
                        type="text"
                        field={form_invitations[:invitee_email]}
                        placeholder="Email a friend..."
                        phx-keydown={!form.data.id && JS.push("discard", target: @myself)}
                        phx-blur={form.data.id && JS.dispatch("submit", to: "##{form.id}")}
                        phx-target={@myself}
                      />
                    </.inputs_for>
                  </div>

              </div>
            </div>
          </.simple_form>
        </div>
      </div>
      <.button
        :if={
          assigns.scope.current_user_id == @renku_initiator_id && (@line_count == 0 || @line_count < @max_lines)
          || assigns.scope.current_user && (@current_invitee_email && assigns.scope.current_user.email == @current_invitee_email)}
        phx-click={JS.push("new", value: %{at: -1, renku_id: @renku.id}, target: @myself)}
        class="mt-4"
      >
        New Line
      </.button>
      <.button
      :if={
        assigns.scope.current_user_id == @renku_initiator_id
        && @line_count == @max_lines
        && is_nil(@renku.published_at)
      }
      phx-click={JS.push("publish", value: %{at: -1, renku_id: @renku.id}, target: @myself)}
      class="mt-4"
      >
      Publish
      </.button>
    </div>
    """
  end

  def update(%{event: %Events.LineAdded{line: line}}, socket) do
    socket = if line.position < socket.assigns.max_lines-1 do
      stream_insert(assign(socket, display_invitation_pencil: true), :lines, to_change_form(line, %{}))
    else
      assign(socket, show_new_line: false)
    end
    {:ok, socket}
  end

  def update(%{event: %Events.LineUpdated{line: line}}, socket) do
    {:ok, stream_insert(socket, :lines, to_change_form(line, %{}))}
  end

  def update(%{event: %Events.LineRepositioned{line: line}}, socket) do
    {:ok, stream_insert(socket, :lines, to_change_form(line, %{}), at: line.position)}
  end

  def update(%{event: %Events.LineDeleted{line: line}}, socket) do
    {:ok, stream_delete(socket, :lines, to_change_form(line, %{}))}
  end

  def update(%{renku: renku} = assigns, socket) do
    renku = Repo.preload(renku, :lines)
    line_forms = Enum.map(renku.lines, &to_change_form(&1, %{}))
    max_lines = renku.max_lines
    line_count = Notebooks.line_count_for_renku(renku)
    {:ok,
     socket
     |> assign(
          renku: renku,
          renku_id: renku.id,
          max_lines: max_lines,
          line_count: line_count,
          renku_initiator_id: renku.user_id,
          current_invitee_email: Collaborations.current_invitee_email(renku),
          display_invitation_pencil: false,
          display_invitations: is_nil(renku.published_at),
          show_new_line: line_count < max_lines,
          scope: assigns.scope)
     |> stream(:lines, line_forms)}
  end

  def handle_event("validate", %{"line" => line_params} = params, socket) do
    line = %Line{id: params["id"], renku_id: socket.assigns.renku_id}

    {:noreply, stream_insert(socket, :lines, to_change_form(line, line_params, :validate))}
  end

  def handle_event("save", %{"id" => id, "line" => params}, socket) do
    line = case fetched_line = Notebooks.get_line!(socket.assigns.scope, id) do
      %Line{} -> fetched_line
      _ -> params
    end

    case Notebooks.update_line(socket.assigns.scope, line, params) do
      {:ok, updated_line} ->
        {:noreply, stream_insert(socket, :lines, to_change_form(updated_line, %{}))}

      {:error, changeset} ->
        {:noreply, stream_insert(socket, :lines, to_change_form(changeset, %{}, :insert))}
    end
  end

  def handle_event("save", %{"line" => params}, socket) do
    #get the renku if the user is allowed to add a line to it. i.e. initiated or has been invited to it
    renku =
      socket.assigns.renku_id
      |> Notebooks.get_renku_if_allowed_to_write!(socket.assigns.scope)
      |> Repo.preload(:user)

    max_lines = renku.max_lines
    line_count = Notebooks.line_count_for_renku(renku)
    case Notebooks.create_line(socket.assigns.scope, renku, params) do
      {:ok, new_line} ->
        empty_form = to_change_form(build_line(socket.assigns.renku_id), %{})
        {:noreply,
         socket
         |> stream_insert(:lines, to_change_form(new_line, %{}))
         |> stream_delete(:lines, empty_form)
        }

      {:error, changeset} ->
        {:noreply, stream_insert(socket, :lines, to_change_form(changeset, params, :insert))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    line = Notebooks.get_line!(socket.assigns.scope, id)
    {:ok, _} = Notebooks.delete_line(socket.assigns.scope, line)

    {:noreply, socket}
  end

  def handle_event("toggle_complete", %{"id" => id}, socket) do
    line = Notebooks.get_line!(socket.assigns.scope, id)
    {:ok, _line} = Notebooks.toggle_complete(socket.assigns.scope, line)

    {:noreply, socket}
  end

  def handle_event("new", %{"at" => at}, socket) do
    line = build_line(socket.assigns.renku_id)
    {:noreply, stream_insert(socket, :lines, to_change_form(line, %{}), at: at)}
  end

  def handle_event("invite", %{"id" => line_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/lines/#{line_id}/invitations/new")}
  end

  def handle_event("publish", _params, socket) do
    renku = Notebooks.get_renku!(socket.assigns.scope, socket.assigns.renku_id)
    Notebooks.publish_renku(socket.assigns.scope, renku)
    assign(socket, renku_published: true)

    {:noreply, push_navigate(socket, to: ~p"/home")}
  end

  def handle_event("reset", _, socket) do
    line = build_line(socket.assigns.renku_id)
    {:noreply, stream(socket, :lines, [to_change_form(line, %{})], reset: true)}
  end

  def handle_event("reposition", %{"id" => id, "new" => new_idx, "old" => _} = params, socket) do
    case params do
      %{"renku_id" => old_renku_id, "to" => %{"renku_id" => old_renku_id}} ->
        line = Notebooks.get_line!(socket.assigns.scope, id)
        Notebooks.update_line_position(socket.assigns.scope, line, new_idx)
        {:noreply, socket}

      %{"renku_id" => _old_renku_id, "to" => %{"renku_id" => new_renku_id}} ->
        line = Notebooks.get_line!(socket.assigns.scope, id)
        renku = Notebooks.get_renku!(socket.assigns.scope, new_renku_id)
        Notebooks.move_line_to_renku(socket.assigns.scope, line, renku, new_idx)
        {:noreply, socket}
    end
  end

  def handle_event("discard", _params, socket) do
    line = build_line(socket.assigns.renku_id)
    {:noreply, stream_delete(socket, :lines, to_change_form(line, %{}))}
  end

  def handle_event("restore_if_unsaved", %{"value" => val} = params, socket) do
    id = params["id"]
    line = Notebooks.get_line!(socket.assigns.scope, id)

    if line.title == val do
      {:noreply, socket}
    else
      {:noreply, stream_insert(socket, :lines, to_change_form(line, %{}))}
    end
  end

  defp to_change_form(line_or_changeset, params, action \\ nil) do
    changeset =
      line_or_changeset
      |> Notebooks.change_line(params)
      # merge with data from params
      |> cast_assoc(:invitations, with: &Linku.Collaborations.Invitation.changeset/2)
      |> Map.put(:action, action)

    to_form(changeset, as: "line", id: "form-#{changeset.data.renku_id}-#{changeset.data.id}")
  end

  defp build_line(renku_id), do: %Line{renku_id: renku_id}
end
