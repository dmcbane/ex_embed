defmodule ExEmbed.HFClient do
  @moduledoc """
  Thin client for the HuggingFace Hub API.
  Used to resolve current file listings and sizes before download,
  ensuring we never rely solely on the vendored registry for byte-level details.
  """

  @base_url "https://huggingface.co/api"
  @req_timeout 30_000

  @doc """
  Fetch model metadata from the HF Hub API.
  Returns `{:ok, %{siblings: [...], ...}}` or `{:error, reason}`.
  """
  @spec model_info(String.t()) :: {:ok, map()} | {:error, term()}
  def model_info(hf_repo) do
    url = "#{@base_url}/models/#{encode_path(hf_repo)}"

    case Req.get(url, headers: req_headers(), receive_timeout: @req_timeout) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: 404}} -> {:error, {:not_found, hf_repo}}
      {:ok, %{status: status}} -> {:error, {:http_error, status}}
      {:error, _reason} -> {:error, :network_error}
    end
  end

  @doc """
  Resolve the download URL for a specific file in a HF repo.
  Uses the resolve endpoint which follows LFS pointers correctly.
  """
  @spec resolve_url(String.t(), String.t()) :: String.t()
  def resolve_url(hf_repo, filename) do
    "https://huggingface.co/#{encode_path(hf_repo)}/resolve/main/#{encode_path(filename)}"
  end

  @doc """
  Stream-download a file from HF to a local path.
  Returns `:ok` or `{:error, reason}`.
  """
  @spec download_file(String.t(), String.t(), Path.t()) :: :ok | {:error, term()}
  def download_file(hf_repo, filename, dest_path) do
    url = resolve_url(hf_repo, filename)

    with :ok <- File.mkdir_p(Path.dirname(dest_path)) do
      case Req.get(url, headers: req_headers(), into: File.stream!(dest_path), receive_timeout: 600_000) do
        {:ok, %{status: 200}} -> :ok
        {:ok, %{status: 404}} -> {:error, {:not_found, filename}}
        {:ok, %{status: status}} -> {:error, {:http_error, status}}
        {:error, _reason} -> {:error, :network_error}
      end
    end
  end

  # Encode path segments, preserving forward slashes
  defp encode_path(path) do
    path
    |> String.split("/")
    |> Enum.map(&URI.encode_www_form/1)
    |> Enum.join("/")
  end

  defp req_headers do
    case System.get_env("HF_TOKEN") do
      nil -> []
      token when is_binary(token) and byte_size(token) > 0 -> [{"Authorization", "Bearer #{token}"}]
      _ -> []
    end
  end
end
