defmodule LinkuWeb.JournalLive do
  use LinkuWeb, :live_view

  alias Linku.{Events, Notebooks}

  def render(assigns) do
    ~H"""
    <div id="home" class="space-y-5">
      <.header>
        Published Renkus
      </.header>
      <div
        id="renkus"
        class="grid grid-cols-1"
      >
        <div
          :for={{id, renku} <- @streams.renkus}
          id={id}
          data-id={renku.id}
          class="bg-gray-100 py-4 rounded-lg my-4"
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

  def mount(_params, _session, socket) do
    renkus = Notebooks.published_renkus()

    {:ok,
     socket
     |> stream(:renkus, renkus)}
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
