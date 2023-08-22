defmodule LinkuWeb.HomeLive do
  use LinkuWeb, :live_view

  alias Linku.{Events, Notebooks, ActivityLog}
  alias LinkuWeb.Timeline

  def render(assigns) do
    ~H"""
    <div id="home" class="space-y-5">
      <.header>
        Your Renkus
        <:actions>
          <.link patch={~p"/renkus/new"}>
            <.button>New Renku</.button>
          </.link>
        </:actions>
      </.header>
      <div
        id="renkus"
        phx-update="stream"
        phx-hook="Sortable"
        class="grid sm:grid-cols-1 md:grid-cols-3 gap-2"
      >
        <div
          :for={{id, renku} <- @streams.renkus}
          id={id}
          data-id={renku.id}
          class="bg-gray-100 py-4 rounded-lg"
        >
          <div class="mx-auto max-w-7xl px-4 space-y-4">
            <.header>
              <%= renku.title %>
              <:actions>
                <.link patch={~p"/renkus/#{renku}/edit"} alt="Edit renku">
                  <.icon name="hero-pencil-square" />
                </.link>
                <.link phx-click="delete-renku" phx-value-id={renku.id} alt="delete renku" data-confirm="Are you sure?">
                  <.icon name="hero-x-mark" />
                </.link>
              </:actions>
            </.header>
            <.live_component
              id={renku.id}
              module={LinkuWeb.RenkuComponent}
              scope={@scope}
              renku={renku}
              max_lines={renku.max_lines}
              line_count={length(renku.lines)}
            />
          </div>
        </div>
      </div>
      <Timeline.activity_logs stream={@streams.activity_logs} page={@page} end_of_timeline?={@end_of_timeline?}/>
    </div>
    <.modal
      :if={@live_action in [:new_renku, :edit_renku]}
      id="renku-modal"
      show
      on_cancel={JS.patch(~p"/")}
    >
      <.live_component
        scope={@scope}
        module={LinkuWeb.RenkuLive.FormComponent}
        id={@renku.id || :new}
        title={@page_title}
        action={@live_action}
        renku={@renku}
        patch={~p"/"}
      />
    </.modal>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Notebooks.subscribe(socket.assigns.scope)
    end

    renkus = Notebooks.active_renkus(socket.assigns.scope, 20)

    {:ok,
     socket
     |> assign(page: 1, per_page: 20)
     |> stream(:renkus, renkus)
     |> paginate_logs(1)}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :dashboard, _params) do
    socket
    |> assign(:page_title, "Dashboard")
    |> assign(:renku, nil)
  end

  defp apply_action(socket, :new_renku, _params) do
    socket
    |> assign(:page_title, "New Renku")
    |> assign(:renku, %Notebooks.Renku{})
  end

  defp apply_action(socket, :edit_renku, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Renku")
    |> assign(:renku, Notebooks.get_renku!(socket.assigns.scope, id))
  end

  def handle_info({Linku.Notebooks, %Events.RenkuAdded{renku: renku} = event}, socket) do
    {:noreply,
     socket
     |> stream_insert(:renkus, renku)
     |> stream_new_log(event)}
  end

  def handle_info({Linku.Notebooks, %Events.RenkuUpdated{renku: renku} = event}, socket) do
    {:noreply,
     socket
     |> stream_insert(:renkus, renku)
     |> stream_new_log(event)}
  end

  def handle_info({Linku.Notebooks, %Events.RenkuPublished{renku: renku} = event}, socket) do
    {:noreply,
     socket
     |> stream_insert(:renkus, renku)
     |> stream_new_log(event)}
  end

  def handle_info({Linku.Notebooks, %Events.RenkuDeleted{renku: renku} = event}, socket) do
    {:noreply,
     socket
     |> stream_delete(:renkus, renku)
     |> stream_new_log(event)}
  end

  def handle_info({Linku.Notebooks, %_event{line: line} = event}, socket) do
    send_update(LinkuWeb.RenkuComponent, id: line.renku_id, event: event)
    {:noreply, stream_new_log(socket, event)}
  end

  def handle_info({Linku.Notebooks, %Events.RenkuRepositioned{renku: renku} = event}, socket) do
    {:noreply,
     socket
     |> stream_insert(:renkus, renku, at: renku.position)
     |> stream_new_log(event)}
  end

  def handle_event("reposition", %{"id" => id, "new" => new_idx, "old" => _old_idx}, socket) do
    renku = Notebooks.get_renku!(socket.assigns.scope, id)
    Notebooks.update_renku_position(socket.assigns.scope, renku, new_idx)
    {:noreply, socket}
  end

  def handle_event("delete-renku", %{"id" => id}, socket) do
    renku = Notebooks.get_renku!(socket.assigns.scope, id)
    Notebooks.delete_renku(socket.assigns.scope, renku)
    {:noreply, socket}
  end

  def handle_event("top", _, socket) do
    {:noreply, socket |> put_flash(:info, "You reached the top") |> paginate_logs(1)}
  end

  def handle_event("next-page", _, socket) do
    {:noreply, paginate_logs(socket, socket.assigns.page + 1)}
  end

  def handle_event("prev-page", %{"_overran" => true}, socket) do
    {:noreply, paginate_logs(socket, 1)}
  end

  def handle_event("prev-page", _, socket) do
    if socket.assigns.page > 1 do
      {:noreply, paginate_logs(socket, socket.assigns.page - 1)}
    else
      {:noreply, socket}
    end
  end

  defp stream_new_log(socket, %_{log: %ActivityLog.Entry{} = log} = _event) do
    stream_insert(socket, :activity_logs, log, at: 0)
  end

  defp stream_new_log(socket, %_{} = _event) do
    socket
  end

  defp paginate_logs(socket, new_page) when new_page >= 1 do
    %{per_page: per_page, page: cur_page, scope: scope} = socket.assigns
    logs = ActivityLog.list_user_logs(scope, offset: (new_page - 1) * per_page, limit: per_page)

    {logs, at, limit} =
      if new_page >= cur_page do
        {logs, -1, per_page * 3 * -1}
      else
        {Enum.reverse(logs), 0, per_page * 3}
      end

    case logs do
      [] ->
        socket
        |> assign(end_of_timeline?: at == -1)
        |> stream(:activity_logs, [])

      [_ | _] = logs ->
        socket
        |> assign(end_of_timeline?: false)
        |> assign(page: if(logs == [], do: cur_page, else: new_page))
        |> stream(:activity_logs, logs, at: at, limit: limit)
    end
  end
end
