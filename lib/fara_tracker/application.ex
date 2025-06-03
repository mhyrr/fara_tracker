defmodule FaraTracker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FaraTrackerWeb.Telemetry,
      FaraTracker.Repo,
      {DNSCluster, query: Application.get_env(:fara_tracker, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FaraTracker.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: FaraTracker.Finch},
      # Start a worker by calling: FaraTracker.Worker.start_link(arg)
      # {FaraTracker.Worker, arg},
      # Start to serve requests, typically the last entry
      FaraTrackerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FaraTracker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FaraTrackerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
