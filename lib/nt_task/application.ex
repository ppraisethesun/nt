defmodule NtTask.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NtTaskWeb.Telemetry,
      NtTask.Repo,
      {DNSCluster, query: Application.get_env(:nt_task, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: NtTask.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: NtTask.Finch},
      # Start a worker by calling: NtTask.Worker.start_link(arg)
      # {NtTask.Worker, arg},
      # Start to serve requests, typically the last entry
      NtTaskWeb.Endpoint,
      {Task.Supervisor, name: NtTask.TaskSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NtTask.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NtTaskWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
