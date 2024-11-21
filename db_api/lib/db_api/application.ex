defmodule DbApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DbApiWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:db_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DbApi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: DbApi.Finch},
      # Start a worker by calling: DbApi.Worker.start_link(arg)
      # {DbApi.Worker, arg},
      # Start to serve requests, typically the last entry
      DbApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DbApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DbApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
