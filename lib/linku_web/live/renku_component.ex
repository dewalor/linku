defmodule LinkuWeb.RenkuComponent do
  use LinkuWeb, :live_component

  alias Linku.{Events, Notebooks}
  alias Linku.Notebooks.Line

  def render(assigns) do
    ~H"""
    <div>
      <div
        id={"lines-#{@renku_id}"}
        phx-update="stream"
        phx-hook="Sortable"
        class="grid grid-cols-1 gap-2"
        data-group="lines"
        data-renku_id={@renku_id}
      >
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
                  placeholder="New line..."
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
        add line
      </.button>
      <.button phx-click={JS.push("reset", target: @myself)} class="mt-4">reset</.button>
    </div>
    """
  end

  def update(%{event: %Events.LineToggled{line: line}}, socket) do
    {:ok, stream_insert(socket, :lines, to_change_form(line, %{}))}
  end

  def update(%{event: %Events.LineAdded{line: line}}, socket) do
    {:ok, stream_insert(socket, :lines, to_change_form(line, %{}))}
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
    line_forms = Enum.map(renku.lines, &to_change_form(&1, %{}))

    {:ok,
     socket
     |> assign(renku_id: renku.id, scope: assigns.scope)
     |> stream(:lines, line_forms)}
  end

  def handle_event("validate", %{"line" => line_params} = params, socket) do
    line = %Line{id: params["id"], renku_id: socket.assigns.renku_id}

    {:noreply, stream_insert(socket, :lines, to_change_form(line, line_params, :validate))}
  end

  def handle_event("save", %{"id" => id, "line" => params}, socket) do
    line = Notebooks.get_line!(socket.assigns.scope, id)

    case Notebooks.update_line(socket.assigns.scope, line, params) do
      {:ok, updated_line} ->
        {:noreply, stream_insert(socket, :lines, to_change_form(updated_line, %{}))}

      {:error, changeset} ->
        {:noreply, stream_insert(socket, :lines, to_change_form(changeset, %{}, :insert))}
    end
  end

  def handle_event("save", %{"line" => params}, socket) do
    renku = Notebooks.get_renku!(socket.assigns.scope, socket.assigns.renku_id)

    case Notebooks.create_line(socket.assigns.scope, renku, params) do
      {:ok, new_line} ->
        empty_form = to_change_form(build_line(socket.assigns.renku_id), %{})

        {:noreply,
         socket
         |> stream_insert(:lines, to_change_form(new_line, %{}))
         |> stream_delete(:lines, empty_form)
         |> stream_insert(:lines, empty_form)}

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
      |> Map.put(:action, action)

    to_form(changeset, as: "line", id: "form-#{changeset.data.renku_id}-#{changeset.data.id}")
  end

  defp build_line(renku_id), do: %Line{renku_id: renku_id}
end
