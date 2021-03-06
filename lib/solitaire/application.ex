defmodule Solitaire.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    :ok = Solitaire.Statix.connect()
    # List all child processes to be supervised
    children = [
      Solitaire.Game.Supervisor,
      {Phoenix.PubSub, [name: Solitaire.PubSub, adapter: Phoenix.PubSub.PG2]},
      # Start the endpoint when the application starts
      SolitaireWeb.Endpoint
      # Starts a worker by calling: Solitaire.Worker.start_link(arg)
      # {Solitaire.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Solitaire.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    SolitaireWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
