defmodule ExEmbed.HFClient do
  @moduledoc """
  Thin client for the HuggingFace Hub API.
  Used to resolve current file listings and sizes before download,
  ensuring we never rely solely on the vendored registry for byte-level details.
  """

  @base_url "https://huggingface.co/api"
  @req_timeout 30_000
  @download_timeout 600_000
  @max_retries 3
  @retry_base_ms 500

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

  When `revision` is provided, uses that instead of "main".
  """
  @spec resolve_url(String.t(), String.t(), String.t()) :: String.t()
  def resolve_url(hf_repo, filename, revision \\ "main") do
    "https://huggingface.co/#{encode_path(hf_repo)}/resolve/#{encode_path(revision)}/#{encode_path(filename)}"
  end

  @doc """
  Stream-download a file from HF to a local path.

  Downloads to a `.tmp` file first, then atomically renames on success.
  Retries up to 3 times with exponential backoff on network errors.
  Returns `:ok` or `{:error, reason}`.
  """
  @spec download_file(String.t(), String.t(), Path.t(), keyword()) :: :ok | {:error, term()}
  def download_file(hf_repo, filename, dest_path, opts \\ []) do
    revision = Keyword.get(opts, :revision, "main")
    url = resolve_url(hf_repo, filename, revision)
    tmp_path = dest_path <> ".tmp"

    with :ok <- File.mkdir_p(Path.dirname(dest_path)) do
      result = download_with_retry(url, tmp_path, @max_retries)

      case result do
        :ok ->
          File.rename(tmp_path, dest_path)

        {:error, _} = err ->
          File.rm(tmp_path)
          err
      end
    end
  end

  defp download_with_retry(_url, _tmp_path, 0), do: {:error, :network_error}

  defp download_with_retry(url, tmp_path, retries_left) do
    result =
      try do
        Req.get(url, headers: req_headers(), into: File.stream!(tmp_path), receive_timeout: @download_timeout)
      rescue
        _e -> {:error, :download_io_error}
      end

    case result do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: 404}} ->
        {:error, {:not_found, Path.basename(tmp_path, ".tmp")}}

      {:ok, %{status: status}} when status in [429, 500, 502, 503, 504] and retries_left > 1 ->
        backoff_ms = @retry_base_ms * :math.pow(2, @max_retries - retries_left) |> round()
        jitter = :rand.uniform(backoff_ms)
        Process.sleep(backoff_ms + jitter)
        File.rm(tmp_path)
        download_with_retry(url, tmp_path, retries_left - 1)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, _} when retries_left > 1 ->
        backoff_ms = @retry_base_ms * :math.pow(2, @max_retries - retries_left) |> round()
        jitter = :rand.uniform(backoff_ms)
        Process.sleep(backoff_ms + jitter)
        File.rm(tmp_path)
        download_with_retry(url, tmp_path, retries_left - 1)

      {:error, _} ->
        {:error, :network_error}
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
