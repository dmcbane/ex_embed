defmodule ExEmbed.Application do
  @moduledoc false
  use Application

  @impl true
  @spec start(Application.start_type(), term()) :: {:ok, pid()} | {:error, term()}
  def start(_type, _args) do
    children = [ExEmbed.Cache] ++ serving_children()

    opts = [strategy: :one_for_one, name: ExEmbed.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp serving_children do
    case Application.get_env(:ex_embed, :serving) do
      nil -> []
      opts when is_list(opts) -> [{ExEmbed.Serving, opts}]
    end
  end
end
