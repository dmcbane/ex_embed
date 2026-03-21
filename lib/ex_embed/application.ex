defmodule ExEmbed.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExEmbed.Cache
    ]

    opts = [strategy: :one_for_one, name: ExEmbed.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
