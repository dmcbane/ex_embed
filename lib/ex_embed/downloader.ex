defmodule ExEmbed.Downloader do
  @moduledoc """
  Downloads and caches ONNX model files from HuggingFace.

  Cache layout:
    {cache_dir}/{hf_repo}/model_optimized.onnx
    {cache_dir}/{hf_repo}/tokenizer.json

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
    with {:ok, meta} <- Registry.get(model_name),
         {:ok, cache_path} <- model_cache_path(meta.hf_repo) do
      files = [meta.model_file | meta.additional_files]
      checksums = Map.get(meta, :checksums, %{}) || %{}

      with :ok <- validate_filenames(files, cache_path) do
        # Files are "needed" if missing or if they fail checksum verification
        needed =
          Enum.filter(files, fn f ->
            dest = Path.join(cache_path, f)

            cond do
              not File.exists?(dest) -> true
              Map.has_key?(checksums, f) -> not checksum_matches?(dest, checksums[f])
              true -> false
            end
          end)

        if needed == [] do
          {:ok, cache_path}
        else
          # If files exist but have bad checksums, delete them first
          Enum.each(needed, fn f ->
            dest = Path.join(cache_path, f)
            if File.exists?(dest), do: File.rm(dest)
          end)

          Logger.info("[ExEmbed] Downloading #{length(needed)} file(s)")

          with {:ok, cache_path} <- download_files(meta.hf_repo, needed, cache_path) do
            verify_checksums(needed, cache_path, checksums)
          end
        end
      end
    end
  end

  @doc """
  Return the local cache path for a model, validating against path traversal.
  Returns `{:ok, path}` or `{:error, :invalid_path}`.
  """
  @spec model_cache_path(String.t()) :: {:ok, Path.t()} | {:error, :invalid_path}
  def model_cache_path(hf_repo) do
    base = cache_dir()
    expanded_base = Path.expand(base)
    candidate = Path.join([expanded_base, hf_repo])
    resolved = Path.expand(candidate)

    if String.starts_with?(resolved, expanded_base <> "/") do
      # Ensure the cache directory structure exists
      File.mkdir_p(resolved)
      {:ok, resolved}
    else
      {:error, :invalid_path}
    end
  end

  defp validate_filenames(files, cache_path) do
    expanded_cache = Path.expand(cache_path)

    invalid =
      Enum.filter(files, fn f ->
        resolved = Path.expand(Path.join(cache_path, f))
        not String.starts_with?(resolved, expanded_cache <> "/")
      end)

    if invalid == [] do
      :ok
    else
      {:error, {:invalid_path, invalid}}
    end
  end

  defp download_files(hf_repo, files, cache_path) do
    results =
      Enum.map(files, fn filename ->
        dest = Path.join(cache_path, filename)

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

  defp verify_checksums(files, cache_path, checksums) do
    bad =
      Enum.filter(files, fn f ->
        case Map.get(checksums, f) do
          nil -> false
          expected -> not checksum_matches?(Path.join(cache_path, f), expected)
        end
      end)

    if bad == [] do
      {:ok, cache_path}
    else
      # Delete corrupted files
      Enum.each(bad, fn f -> File.rm(Path.join(cache_path, f)) end)
      {:error, {:checksum_mismatch, bad}}
    end
  end

  defp checksum_matches?(file_path, expected_sha256) do
    actual =
      File.stream!(file_path, 65_536)
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    actual == expected_sha256
  end

  defp cache_dir do
    Application.get_env(:ex_embed, :cache_dir) ||
      Path.join([System.user_home!(), ".cache", "ex_embed"])
  end
end
