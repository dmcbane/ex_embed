defmodule ExEmbed.HFClient do
  @moduledoc """
  Thin client for the HuggingFace Hub API.
  Used to resolve current file listings and sizes before download,
  ensuring we never rely solely on the vendored registry for byte-level details.
  """

  @base_url "https://huggingface.co/api"

  @doc """
  Fetch model metadata from the HF Hub API.
  Returns `{:ok, %{siblings: [...], ...}}` or `{:error, reason}`.
  """
  @spec model_info(String.t()) :: {:ok, map()} | {:error, term()}
  def model_info(hf_repo) do
    url = "#{@base_url}/models/#{hf_repo}"

    case Req.get(url, headers: req_headers()) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 404}} -> {:error, {:not_found, hf_repo}}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resolve the download URL for a specific file in a HF repo.
  Uses the resolve endpoint which follows LFS pointers correctly.
  """
  @spec resolve_url(String.t(), String.t()) :: String.t()
  def resolve_url(hf_repo, filename) do
    "https://huggingface.co/#{hf_repo}/resolve/main/#{filename}"
  end

  @doc """
  Stream-download a file from HF to a local path.
  Returns `:ok` or `{:error, reason}`.
  """
  @spec download_file(String.t(), String.t(), Path.t()) :: :ok | {:error, term()}
  def download_file(hf_repo, filename, dest_path) do
    url = resolve_url(hf_repo, filename)

    File.mkdir_p!(Path.dirname(dest_path))

    case Req.get(url, headers: req_headers(), into: File.stream!(dest_path)) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: 404}} -> {:error, {:not_found, url}}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp req_headers do
    case System.get_env("HF_TOKEN") do
      nil -> []
      token -> [{"Authorization", "Bearer #{token}"}]
    end
  end
end
