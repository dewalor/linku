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
            </.header>
            <.live_component
              id={renku.id}
              module={LinkuWeb.RenkuComponent}
              scope={@scope}
              renku={renku}
            />
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
