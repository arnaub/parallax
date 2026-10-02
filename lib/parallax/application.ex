defmodule Parallax.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ParallaxWeb.Telemetry,
      Parallax.Repo,
      {DNSCluster,
       query: Application.get_env(:parallax, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Parallax.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Parallax.Finch},
      # Start a worker by calling: Parallax.Worker.start_link(arg)
      # {Parallax.Worker, arg},
      # Start to serve requests, typically the last entry
      ParallaxWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Parallax.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ParallaxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
