defmodule Mix.Tasks.ExEmbed.CheckRegistry do
  @shortdoc "Diff vendored registry against FastEmbed upstream"
  @moduledoc """
  Fetches FastEmbed's supported models notebook from GitHub and compares
  model names against the local vendored registry. Prints any additions
  or removals so you know when to update `priv/registry/models.json`.

      mix ex_embed.check_registry
  """

  use Mix.Task

  @fastembed_notebook_url "https://raw.githubusercontent.com/qdrant/fastembed/main/docs/examples/Supported_Models.ipynb"

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:req)

    Mix.shell().info("Fetching FastEmbed supported models list...")

    case Req.get(@fastembed_notebook_url) do
      {:ok, %{status: 200, body: body}} ->
        upstream_names = parse_model_names(body)
        local_names = MapSet.new(ExEmbed.Registry.list())

        added = MapSet.difference(upstream_names, local_names)
        removed = MapSet.difference(local_names, upstream_names)

        if MapSet.size(added) == 0 and MapSet.size(removed) == 0 do
          Mix.shell().info("✓ Registry is in sync with FastEmbed upstream.")
        else
          unless MapSet.size(added) == 0 do
            Mix.shell().info("\nModels in FastEmbed but NOT in local registry (consider adding):")
            added |> Enum.sort() |> Enum.each(&Mix.shell().info("  + #{&1}"))
          end

          unless MapSet.size(removed) == 0 do
            Mix.shell().info("\nModels in local registry but NOT in FastEmbed upstream:")
            removed |> Enum.sort() |> Enum.each(&Mix.shell().info("  - #{&1}"))
          end
        end

      {:ok, %{status: status}} ->
        Mix.raise("Failed to fetch upstream list (HTTP #{status})")

      {:error, reason} ->
        Mix.raise("Network error: #{inspect(reason)}")
    end
  end

  defp parse_model_names(body) when is_binary(body) do
    # Extract model names from the notebook JSON source
    # Looks for patterns like "BAAI/bge-small-en-v1.5" in cell source
    Regex.scan(~r/([A-Za-z0-9_\-]+\/[A-Za-z0-9_\-\.]+)/, body)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.filter(&String.contains?(&1, "/"))
    |> Enum.reject(&String.starts_with?(&1, "http"))
    |> MapSet.new()
  end

  defp parse_model_names(body) when is_map(body) do
    body |> Jason.encode!() |> parse_model_names()
  end
end
