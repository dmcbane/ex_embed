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

      embedding = Nx.Serving.run(MyApp.EmbeddingServing, "my text")
      # embedding is an Nx.Tensor of shape {1, dim}

  For a list of texts (returns {n, dim} tensor):

      embeddings = Nx.Serving.run(MyApp.EmbeddingServing, ["text one", "text two"])
  """

  alias ExEmbed.{Cache, Pipeline}

  @doc """
  Build an `Nx.Serving` for the given model.
  The model is loaded/downloaded via `ExEmbed.Cache` on first call.

  Accepts string or list-of-strings input via `Nx.Serving.run/2`.
  """
  @spec new(String.t()) :: Nx.Serving.t()
  def new(model_name \\ ExEmbed.Registry.default()) do
    Nx.Serving.new(fn _opts ->
      # The batch_fun receives the dummy batch from preprocessing.
      # It returns a matching tensor so Nx.Serving's internal slicing works.
      # The real embedding result is carried in client_info.
      fn batch ->
        Nx.broadcast(Nx.tensor(0.0), {batch.size, 1})
      end
    end)
    |> Nx.Serving.client_preprocessing(fn input ->
      texts = List.wrap(input)
      {:ok, {model, tokenizer}} = Cache.fetch(model_name)

      case Pipeline.embed(texts, model, tokenizer) do
        {:ok, tensor} ->
          # Send a 1-element dummy batch through the serving machinery.
          # The real embedding tensor is carried as client_info.
          {Nx.Batch.stack([Nx.tensor([0])]), tensor}

        {:error, reason} ->
          raise "ExEmbed.Serving inference failed: #{inspect(reason)}"
      end
    end)
    |> Nx.Serving.client_postprocessing(fn {_dummy, _server_info}, tensor ->
      tensor
    end)
  end
end
