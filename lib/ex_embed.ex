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

    with {:ok, {model, tokenizer}} <- Cache.fetch(model_name) do
      Pipeline.embed(texts, model, tokenizer)
    end
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
end
