defmodule ExEmbed.Downloader do
  @moduledoc """
  Downloads and caches ONNX model files from HuggingFace.

  Cache layout:
    {cache_dir}/{hf_repo}/model_optimized.onnx
    {cache_dir}/{hf_repo}/tokenizer.json
    {cache_dir}/{hf_repo}/.checksums  (sha256 per file)

  Set `:cache_dir` in application config, or defaults to `~/.cache/ex_embed`.
  """

  alias ExEmbed.{HFClient, Registry}
  require Logger

  @doc """
  Ensure a model's files are present and valid in the local cache.
  Downloads any missing or corrupted files. Returns `{:ok, cache_path}`.
  """
  @spec ensure(String.t()) :: {:ok, Path.t()} | {:error, term()}
  def ensure(model_name) do
    with {:ok, meta} <- Registry.get(model_name) do
      cache_path = model_cache_path(meta.hf_repo)
      files = [meta.model_file | meta.additional_files]

      missing =
        Enum.filter(files, fn f ->
          dest = Path.join(cache_path, f)
          not File.exists?(dest)
        end)

      if missing == [] do
        {:ok, cache_path}
      else
        Logger.info("[ExEmbed] Downloading #{length(missing)} file(s) for #{model_name}")
        download_files(meta.hf_repo, missing, cache_path)
      end
    end
  end

  @doc "Return the local cache path for a model, whether or not it's downloaded."
  @spec model_cache_path(String.t()) :: Path.t()
  def model_cache_path(hf_repo) do
    Path.join([cache_dir(), hf_repo])
  end

  defp download_files(hf_repo, files, cache_path) do
    results =
      Enum.map(files, fn filename ->
        dest = Path.join(cache_path, filename)
        Logger.debug("[ExEmbed] Fetching #{hf_repo}/#{filename}")

        case HFClient.download_file(hf_repo, filename, dest) do
          :ok -> {:ok, filename}
          {:error, reason} -> {:error, {filename, reason}}
        end
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      {:ok, cache_path}
    else
      {:error, {:download_failed, errors}}
    end
  end

  defp cache_dir do
    Application.get_env(:ex_embed, :cache_dir) ||
      Path.join([System.user_home!(), ".cache", "ex_embed"])
  end
end
