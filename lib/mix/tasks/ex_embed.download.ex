defmodule Mix.Tasks.ExEmbed.Download do
  @shortdoc "Download a model to the local cache"
  @moduledoc """
  Downloads a registered model's ONNX and tokenizer files to the local cache.

      mix ex_embed.download bge-small-en-v1.5
      mix ex_embed.download BAAI/bge-small-en-v1.5

  If the model is already cached and valid, this is a no-op.
  """

  use Mix.Task

  @impl Mix.Task
  def run([]) do
    Mix.shell().error("Usage: mix ex_embed.download <model_name>")
    Mix.shell().info("Run `mix ex_embed.list` to see available models.")
  end

  def run([partial_name | _]) do
    Application.ensure_all_started(:ex_embed)

    model_name = resolve_name(partial_name)

    Mix.shell().info("Ensuring #{model_name} is downloaded...")

    case ExEmbed.Downloader.ensure(model_name) do
      {:ok, path} ->
        Mix.shell().info("✓ #{model_name} ready at #{path}")

      {:error, {:not_found, _}} ->
        Mix.shell().error("Model not found in registry: #{model_name}")
        Mix.shell().info("Run `mix ex_embed.list` to see available models.")

      {:error, reason} ->
        Mix.shell().error("Download failed: #{inspect(reason)}")
    end
  end

  # Accept short names like "bge-small-en-v1.5" in addition to full "BAAI/bge-small-en-v1.5"
  defp resolve_name(name) do
    if String.contains?(name, "/") do
      name
    else
      all = ExEmbed.Registry.list()
      Enum.find(all, name, fn m -> String.ends_with?(m, "/" <> name) end)
    end
  end
end
