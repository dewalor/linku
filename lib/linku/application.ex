defmodule Linku.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LinkuWeb.Telemetry,
      Linku.Repo,
      {Phoenix.PubSub, name: Linku.PubSub},
      {Finch, name: Linku.Finch},
      LinkuWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Linku.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    LinkuWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
