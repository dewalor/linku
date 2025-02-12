defmodule LinkuWeb.JournalLive do
  use LinkuWeb, :live_view

  alias Linku.{Events, Notebooks, Accounts}

  def render(assigns) do
    ~H"""
    <div class="relative z-10 flex -mt-16 mb-20">
      <%= if @current_user do %>
        <.back navigate={~p"/home"}>Back to Dashboard</.back>
      <% end %>
    </div>
    <div id="feed" class="space-y-5">
      <div
        id="renkus"
        class="grid grid-cols-1"
      >
        <div
          :for={{id, renku} <- @streams.renkus}
          id={id}
          data-id={renku.id}
          class="bg-slate-50 py-4 rounded-lg my-4 opacity-75"
        >
          <div class="mx-auto max-w-7xl px-4 space-y-4">
            <.header>
              <%= renku.title %>
            </.header>
            <div>
              <div
                id={"lines-#{renku.id}"}
                class="grid grid-cols-1 gap-2"
              >
                <div
                  :for={line <- renku.lines}
                  id={id}
                  data-renku_id={renku.id}
                  class="
                  relative flex items-center space-x-3
                  "
                >
                    <div class="flex">
                      <div class="flex-auto">
                        <%= line.title %>
                      </div>
                    </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, session, socket) do
    current_user = with %{"user_token" => token} <- session do
      Accounts.get_user_by_session_token(token)
    else
      _ -> nil
    end

    renkus = Notebooks.published_renkus()
    {:ok,
     socket
     |> assign(current_user: current_user)
     |> stream(:renkus, renkus)}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Linku Renku Feed")
    |> assign(:renku, nil)
  end

  def handle_info({Linku.Notebooks, %Events.RenkuUpdated{renku: renku}}, socket) do
    {:noreply,
     socket
     |> stream_insert(:renkus, renku)}
  end

  def handle_info({Linku.Notebooks, %Events.RenkuPublished{renku: renku}}, socket) do
    {:noreply,
     socket
     |> stream_insert(:renkus, renku)}
  end

  def handle_info({Linku.Notebooks, %Events.RenkuDeleted{renku: renku}}, socket) do
    {:noreply,
     socket
     |> stream_delete(:renkus, renku)}
  end

  def handle_info({Linku.Notebooks, %Events.RenkuRepositioned{renku: renku}}, socket) do
    {:noreply,
     socket
     |> stream_insert(:renkus, renku, at: renku.position)
    }
  end
end
