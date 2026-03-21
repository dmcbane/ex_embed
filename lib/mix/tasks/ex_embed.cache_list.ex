defmodule Mix.Tasks.ExEmbed.CacheList do
  @shortdoc "List cached models on disk with sizes"
  @moduledoc """
  Lists all models currently cached on disk in the ExEmbed cache directory.

      mix ex_embed.cache_list
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    cache_dir =
      Application.get_env(:ex_embed, :cache_dir) ||
        Path.join([System.user_home!(), ".cache", "ex_embed"])

    if not File.dir?(cache_dir) do
      Mix.shell().info("Cache directory does not exist: #{cache_dir}")
    else
      list_models(cache_dir)
    end
  end

  defp list_models(cache_dir) do
    entries =
      cache_dir
      |> File.ls!()
      |> Enum.flat_map(fn org ->
        org_path = Path.join(cache_dir, org)

        if File.dir?(org_path) do
          org_path
          |> File.ls!()
          |> Enum.filter(&File.dir?(Path.join(org_path, &1)))
          |> Enum.map(fn repo ->
            repo_path = Path.join(org_path, repo)
            size_bytes = dir_size(repo_path)
            %{name: "#{org}/#{repo}", path: repo_path, size: size_bytes}
          end)
        else
          []
        end
      end)
      |> Enum.sort_by(& &1.name)

    if entries == [] do
      Mix.shell().info("No cached models found in #{cache_dir}")
    else
      Mix.shell().info("\nCached models (#{cache_dir}):\n")

      Mix.shell().info(
        String.pad_trailing("Model", 50) <>
          String.pad_leading("Size", 12)
      )

      Mix.shell().info(String.duplicate("─", 62))

      total =
        Enum.reduce(entries, 0, fn entry, acc ->
          Mix.shell().info(
            String.pad_trailing(entry.name, 50) <>
              String.pad_leading(format_size(entry.size), 12)
          )

          acc + entry.size
        end)

      Mix.shell().info(String.duplicate("─", 62))

      Mix.shell().info(
        String.pad_trailing("Total (#{length(entries)} models)", 50) <>
          String.pad_leading(format_size(total), 12)
      )

      Mix.shell().info("")
    end
  end

  defp dir_size(path) do
    path
    |> File.ls!()
    |> Enum.reduce(0, fn file, acc ->
      full = Path.join(path, file)

      case File.stat(full) do
        {:ok, %{size: size}} -> acc + size
        _ -> acc
      end
    end)
  end

  defp format_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_size(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_size(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
