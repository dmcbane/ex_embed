defmodule Mix.Tasks.ExEmbed.CacheClean do
  @shortdoc "Remove cached models from disk"
  @moduledoc """
  Removes cached model files from the ExEmbed cache directory.

      # Remove all cached models
      mix ex_embed.cache_clean

      # Remove a specific model
      mix ex_embed.cache_clean bge-small-en-v1.5
  """

  use Mix.Task

  @impl Mix.Task
  def run([]) do
    cache_dir =
      Application.get_env(:ex_embed, :cache_dir) ||
        Path.join([System.user_home!(), ".cache", "ex_embed"])

    if not File.dir?(cache_dir) do
      Mix.shell().info("Cache directory does not exist.")
    else
      Mix.shell().info("Removing all cached models from #{cache_dir}...")

      case File.rm_rf(cache_dir) do
        {:ok, _} ->
          Mix.shell().info("Cache cleared.")

        {:error, reason, path} ->
          Mix.raise("Failed to remove #{path}: #{inspect(reason)}")
      end
    end
  end

  def run([partial_name | _]) do
    cache_dir =
      Application.get_env(:ex_embed, :cache_dir) ||
        Path.join([System.user_home!(), ".cache", "ex_embed"])

    if not File.dir?(cache_dir) do
      Mix.shell().error("No cached model matching '#{partial_name}' found.")
    else
      match =
        cache_dir
        |> File.ls!()
        |> Enum.flat_map(fn org ->
          org_path = Path.join(cache_dir, org)

          if File.dir?(org_path) do
            org_path
            |> File.ls!()
            |> Enum.filter(&File.dir?(Path.join(org_path, &1)))
            |> Enum.map(fn repo -> {org, repo, Path.join(org_path, repo)} end)
          else
            []
          end
        end)
        |> Enum.find(fn {org, repo, _path} ->
          "#{org}/#{repo}" == partial_name or repo == partial_name or
            String.ends_with?(repo, partial_name)
        end)

      case match do
        {org, repo, path} ->
          Mix.shell().info("Removing #{org}/#{repo}...")
          File.rm_rf!(path)
          Mix.shell().info("Removed.")

        nil ->
          Mix.shell().error("No cached model matching '#{partial_name}' found.")
      end
    end
  end
end
