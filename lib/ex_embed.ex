defmodule ExEmbed do
  @moduledoc """
  Elixir-native text embeddings using Ortex (ONNX Runtime) + Tokenizers,
  with a FastEmbed-compatible model registry backed by HuggingFace.

  ## Quick start

      # Add to deps in mix.exs:
      {:ex_embed, "~> 0.1"}

      # Embed some text (auto-downloads model on first use):
      {:ok, tensor} = ExEmbed.embed("Hello, world!")
      # => {:ok, #Nx.Tensor<f32[1][384]>}

      # Embed a batch:
      {:ok, tensor} = ExEmbed.embed(["text one", "text two"], model: "BAAI/bge-base-en-v1.5")

      # List available models:
      ExEmbed.list_models()

  ## Nx.Serving (recommended for production)

      # In your supervision tree:
      {Nx.Serving,
        serving: ExEmbed.Serving.new("BAAI/bge-small-en-v1.5"),
        name: MyApp.EmbeddingServing,
        batch_size: 32,
        batch_timeout: 100}

      # At call time:
      {:ok, vec} = Nx.Serving.run(MyApp.EmbeddingServing, "my text")
  """

  alias ExEmbed.{Cache, Pipeline, Registry}

  @doc """
  Embed one or more texts. Returns `{:ok, tensor}` with shape `{n, dim}`.

  Options:
    - `:model` - model name (default: `"BAAI/bge-small-en-v1.5"`)
  """
  @spec embed(String.t() | [String.t()], keyword()) ::
          {:ok, Nx.Tensor.t()} | {:error, term()}
  def embed(text_or_texts, opts \\ []) do
    model_name = Keyword.get(opts, :model, Registry.default())
    texts = List.wrap(text_or_texts)
    meta = %{model: model_name, batch_size: length(texts)}
    start_time = System.monotonic_time()

    :telemetry.execute([:ex_embed, :embed, :start], %{system_time: System.system_time()}, meta)

    result =
      with {:ok, {model, tokenizer}} <- Cache.fetch(model_name) do
        Pipeline.embed(texts, model, tokenizer)
      end

    duration = System.monotonic_time() - start_time

    case result do
      {:ok, _} ->
        :telemetry.execute([:ex_embed, :embed, :stop], %{duration: duration}, meta)

      {:error, _} ->
        :telemetry.execute([:ex_embed, :embed, :exception], %{duration: duration}, meta)
    end

    result
  end

  @doc """
  Like `embed/2` but raises on error.
  """
  @spec embed!(String.t() | [String.t()], keyword()) :: Nx.Tensor.t()
  def embed!(text_or_texts, opts \\ []) do
    case embed(text_or_texts, opts) do
      {:ok, tensor} -> tensor
      {:error, reason} -> raise "ExEmbed.embed! failed: #{inspect(reason)}"
    end
  end

  @doc "Return a list of all registered model names."
  @spec list_models() :: [String.t()]
  def list_models, do: Registry.list()

  @doc "Preload a model into the cache to avoid latency on first use."
  @spec preload(String.t()) :: :ok | {:error, term()}
  def preload(model_name), do: Cache.preload(model_name)

  @doc "Check if a model is loaded and ready for inference."
  @spec available?(String.t()) :: boolean()
  def available?(model_name \\ Registry.default()), do: Cache.available?(model_name)

  @doc """
  Cosine similarity between two embedding tensors.

  Since embeddings are L2-normalized, this is equivalent to the dot product.
  Returns a float between -1.0 (opposite) and 1.0 (identical).
  """
  @spec similarity(Nx.Tensor.t(), Nx.Tensor.t()) :: float()
  def similarity(vec1, vec2) do
    Nx.dot(Nx.flatten(vec1), Nx.flatten(vec2)) |> Nx.to_number()
  end

  @doc """
  Get model metadata from the registry without loading.

  Returns `{:ok, %{name, dim, hf_repo, ...}}` or `{:error, :not_found}`.
  """
  @spec model_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  def model_info(model_name), do: Registry.get(model_name)

  @doc """
  Verify the full pipeline works for a model by running a dummy embed.

  Returns `:ok` if inference succeeds, or `{:error, reason}` on failure.
  """
  @spec health_check(String.t()) :: :ok | {:error, term()}
  def health_check(model_name \\ Registry.default()) do
    case embed("health check", model: model_name) do
      {:ok, _} -> :ok
      {:error, _} = err -> err
    end
  end
end
