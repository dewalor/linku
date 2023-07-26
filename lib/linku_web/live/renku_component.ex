defmodule LinkuWeb.RenkuComponent do
  use LinkuWeb, :live_component

  alias Linku.{Events, Notebook}
  alias Linku.Notebook.Todo

  def render(assigns) do
    ~H"""
    <div>
      <div
        id={"todos-#{@renku_id}"}
        phx-update="stream"
        phx-hook="Sortable"
        class="grid grid-cols-1 gap-2"
        data-group="todos"
        data-renku_id={@renku_id}
      >
        <div
          :for={{id, form} <- @streams.todos}
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
              <button
                :if={form.data.id}
                type="button"
                phx-click={JS.push("toggle_complete", target: @myself, value: %{id: form.data.id})}
                class="w-10"
              >
                <.icon
                  name="hero-check-circle"
                  class={[
                    "w-7 h-7",
                    if(form[:status].value == :completed, do: "bg-green-600", else: "bg-gray-300")
                  ]}
                />
              </button>
              <div class="flex-auto">
                <input type="hidden" name={form[:status].name} value={form[:status].value} />
                <.input
                  type="text"
                  field={form[:title]}
                  border={false}
                  strike_through={form[:status].value == :completed}
                  placeholder="New todo..."
                  phx-mounted={!form.data.id && JS.focus()}
                  phx-keydown={!form.data.id && JS.push("discard", target: @myself)}
                  phx-key="escape"
                  phx-blur={form.data.id && JS.dispatch("submit", to: "##{form.id}")}
                  phx-target={@myself}
                />
              </div>
              <button
                :if={form.data.id}
                type="button"
                phx-click={
                  JS.push("delete", target: @myself, value: %{id: form.data.id}) |> hide("##{id}")
                }
                class="w-10 -mt-1"
              >
                <.icon name="hero-x-mark" />
              </button>
            </div>
          </.simple_form>
        </div>
      </div>
      <.button
        phx-click={JS.push("new", value: %{at: -1, renku_id: @renku_id}, target: @myself)}
        class="mt-4"
      >
        add todo
      </.button>
      <.button phx-click={JS.push("reset", target: @myself)} class="mt-4">reset</.button>
    </div>
    """
  end

  def update(%{event: %Events.TodoToggled{todo: todo}}, socket) do
    {:ok, stream_insert(socket, :todos, to_change_form(todo, %{}))}
  end

  def update(%{event: %Events.TodoAdded{todo: todo}}, socket) do
    {:ok, stream_insert(socket, :todos, to_change_form(todo, %{}))}
  end

  def update(%{event: %Events.TodoUpdated{todo: todo}}, socket) do
    {:ok, stream_insert(socket, :todos, to_change_form(todo, %{}))}
  end

  def update(%{event: %Events.TodoRepositioned{todo: todo}}, socket) do
    {:ok, stream_insert(socket, :todos, to_change_form(todo, %{}), at: todo.position)}
  end

  def update(%{event: %Events.TodoDeleted{todo: todo}}, socket) do
    {:ok, stream_delete(socket, :todos, to_change_form(todo, %{}))}
  end

  def update(%{renku: renku} = assigns, socket) do
    todo_forms = Enum.map(renku.todos, &to_change_form(&1, %{}))

    {:ok,
     socket
     |> assign(renku_id: renku.id, scope: assigns.scope)
     |> stream(:todos, todo_forms)}
  end

  def handle_event("validate", %{"todo" => todo_params} = params, socket) do
    todo = %Todo{id: params["id"], renku_id: socket.assigns.renku_id}

    {:noreply, stream_insert(socket, :todos, to_change_form(todo, todo_params, :validate))}
  end

  def handle_event("save", %{"id" => id, "todo" => params}, socket) do
    todo = Notebook.get_todo!(socket.assigns.scope, id)

    case Notebook.update_todo(socket.assigns.scope, todo, params) do
      {:ok, updated_todo} ->
        {:noreply, stream_insert(socket, :todos, to_change_form(updated_todo, %{}))}

      {:error, changeset} ->
        {:noreply, stream_insert(socket, :todos, to_change_form(changeset, %{}, :insert))}
    end
  end

  def handle_event("save", %{"todo" => params}, socket) do
    renku = Notebook.get_renku!(socket.assigns.scope, socket.assigns.renku_id)

    case Notebook.create_todo(socket.assigns.scope, renku, params) do
      {:ok, new_todo} ->
        empty_form = to_change_form(build_todo(socket.assigns.renku_id), %{})

        {:noreply,
         socket
         |> stream_insert(:todos, to_change_form(new_todo, %{}))
         |> stream_delete(:todos, empty_form)
         |> stream_insert(:todos, empty_form)}

      {:error, changeset} ->
        {:noreply, stream_insert(socket, :todos, to_change_form(changeset, params, :insert))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    todo = Notebook.get_todo!(socket.assigns.scope, id)
    {:ok, _} = Notebook.delete_todo(socket.assigns.scope, todo)

    {:noreply, socket}
  end

  def handle_event("toggle_complete", %{"id" => id}, socket) do
    todo = Notebook.get_todo!(socket.assigns.scope, id)
    {:ok, _todo} = Notebook.toggle_complete(socket.assigns.scope, todo)

    {:noreply, socket}
  end

  def handle_event("new", %{"at" => at}, socket) do
    todo = build_todo(socket.assigns.renku_id)
    {:noreply, stream_insert(socket, :todos, to_change_form(todo, %{}), at: at)}
  end

  def handle_event("reset", _, socket) do
    todo = build_todo(socket.assigns.renku_id)
    {:noreply, stream(socket, :todos, [to_change_form(todo, %{})], reset: true)}
  end

  def handle_event("reposition", %{"id" => id, "new" => new_idx, "old" => _} = params, socket) do
    case params do
      %{"renku_id" => old_renku_id, "to" => %{"renku_id" => old_renku_id}} ->
        todo = Notebook.get_todo!(socket.assigns.scope, id)
        Notebook.update_todo_position(socket.assigns.scope, todo, new_idx)
        {:noreply, socket}

      %{"renku_id" => _old_renku_id, "to" => %{"renku_id" => new_renku_id}} ->
        todo = Notebook.get_todo!(socket.assigns.scope, id)
        renku = Notebook.get_renku!(socket.assigns.scope, new_renku_id)
        Notebook.move_todo_to_renku(socket.assigns.scope, todo, renku, new_idx)
        {:noreply, socket}
    end
  end

  def handle_event("discard", _params, socket) do
    todo = build_todo(socket.assigns.renku_id)
    {:noreply, stream_delete(socket, :todos, to_change_form(todo, %{}))}
  end

  def handle_event("restore_if_unsaved", %{"value" => val} = params, socket) do
    id = params["id"]
    todo = Notebook.get_todo!(socket.assigns.scope, id)

    if todo.title == val do
      {:noreply, socket}
    else
      {:noreply, stream_insert(socket, :todos, to_change_form(todo, %{}))}
    end
  end

  defp to_change_form(todo_or_changeset, params, action \\ nil) do
    changeset =
      todo_or_changeset
      |> Notebook.change_todo(params)
      |> Map.put(:action, action)

    to_form(changeset, as: "todo", id: "form-#{changeset.data.renku_id}-#{changeset.data.id}")
  end

  defp build_todo(renku_id), do: %Todo{renku_id: renku_id}
end
