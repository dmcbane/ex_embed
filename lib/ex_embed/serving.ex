defmodule ExEmbed.Serving do
  @moduledoc """
  `Nx.Serving`-based embedding server for batched, backpressured inference.

  ## Usage in your supervision tree

      {Nx.Serving,
        serving: ExEmbed.Serving.new("BAAI/bge-small-en-v1.5"),
        name: MyApp.EmbeddingServing,
        batch_size: 32,
        batch_timeout: 100}

  Then at call time:

      {:ok, embedding} = Nx.Serving.run(MyApp.EmbeddingServing, "my text")
      # embedding is a 1D Nx.Tensor of shape {dim}

  For a list of texts (returns {n, dim} tensor):

      {:ok, embeddings} = Nx.Serving.batched_run(MyApp.EmbeddingServing, texts)
  """

  alias ExEmbed.{Cache, Pipeline}

  @doc """
  Build an `Nx.Serving` for the given model.
  The model is loaded/downloaded via `ExEmbed.Cache` on first call.
  """
  @spec new(String.t()) :: Nx.Serving.t()
  def new(model_name \\ ExEmbed.Registry.default()) do
    Nx.Serving.new(fn texts ->
      {:ok, {model, tokenizer}} = Cache.fetch(model_name)

      case Pipeline.embed(List.wrap(texts), model, tokenizer) do
        {:ok, tensor} -> tensor
        {:error, reason} -> raise "ExEmbed.Serving inference failed: #{inspect(reason)}"
      end
    end)
  end
end
