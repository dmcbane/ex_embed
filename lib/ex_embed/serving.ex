defmodule ExEmbed.Serving do
  @moduledoc """
  `Nx.Serving`-based embedding server for batched, backpressured inference.

  Implements `@behaviour Nx.Serving` for proper integration with Nx.Serving's
  batching, partitioning, and backpressure infrastructure.

  ## Inline usage

      serving = ExEmbed.Serving.new("BAAI/bge-small-en-v1.5")
      tensor = Nx.Serving.run(serving, "my text")
      # tensor shape: {1, 384}

  ## Supervised process usage

      # In your supervision tree:
      {Nx.Serving,
        serving: ExEmbed.Serving.new("BAAI/bge-small-en-v1.5"),
        name: MyApp.EmbeddingServing,
        batch_size: 32,
        batch_timeout: 100}

      # At call time:
      tensor = Nx.Serving.batched_run(MyApp.EmbeddingServing, "my text")

  ## Managed process with graceful degradation

      # Uses ExEmbed.Serving.start_link/1 which returns :ignore on failure:
      {ExEmbed.Serving, name: MyApp.EmbeddingServing, batch_timeout: 100}
  """

  @behaviour Nx.Serving

  alias ExEmbed.{Cache, Pipeline, Registry}
  require Logger

  @doc """
  Start a managed Serving process with graceful degradation.

  Returns `{:ok, pid}` on success or `:ignore` if the model fails to load.
  Use this in your supervision tree for fault-tolerant startup.

  ## Options
    - `:model` - model name (default: `Registry.default()`)
    - `:name` - process name (default: `ExEmbed.Serving`)
    - `:batch_size` - max batch size (default: Nx.Serving default)
    - `:batch_timeout` - ms to wait for batch to fill (default: 100)
  """
  @spec start_link(keyword()) :: GenServer.on_start() | :ignore
  def start_link(opts \\ []) do
    model_name = Keyword.get(opts, :model, Registry.default())

    # Validate model is loadable before starting the Serving process.
    # This prevents Nx.Serving.start_link from crashing its supervisor.
    case Cache.fetch(model_name) do
      {:ok, _} ->
        serving = new(model_name)

        serving_opts =
          [serving: serving, name: Keyword.get(opts, :name, __MODULE__)] ++
            Keyword.take(opts, [:batch_size, :batch_timeout])

        Nx.Serving.start_link(serving_opts)

      {:error, reason} ->
        Logger.warning("Serving not started: model unavailable")
        Logger.debug("Serving start failure", reason: inspect(reason))
        :ignore
    end
  rescue
    e ->
      Logger.warning("Serving failed to start")
      Logger.debug("Serving start exception", error: Exception.message(e))
      :ignore
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient
    }
  end

  @doc "Check if a named Serving process is running."
  @spec available?(atom()) :: boolean()
  def available?(name \\ __MODULE__) do
    pid = Process.whereis(name)
    pid != nil and Process.alive?(pid)
  end

  @doc """
  Build an `Nx.Serving` for the given model.

  Accepts string or list-of-strings input via `Nx.Serving.run/2`.
  """
  @spec new(String.t()) :: Nx.Serving.t()
  def new(model_name \\ Registry.default()) do
    Nx.Serving.new(ExEmbed.Serving, model_name)
    |> Nx.Serving.client_preprocessing(fn input ->
      texts = List.wrap(input)
      {:ok, {_model, tokenizer}} = Cache.fetch(model_name)
      {:ok, encodings} = Tokenizers.Tokenizer.encode_batch(tokenizer, texts, add_special_tokens: true)

      {ids, mask, types} = build_tensor_batch(encodings)
      batch = Nx.Batch.concatenate([{ids, mask, types}])

      {batch, :client_info}
    end)
    |> Nx.Serving.client_postprocessing(fn {{hidden, mask}, _server_info}, _client_info ->
      Pipeline.mean_pool_and_normalize(hidden, mask)
    end)
  end

  # ── Nx.Serving callbacks ──────────────────────────────────────────────────

  @impl true
  @spec init(:inline | :process, String.t(), [keyword()]) :: {:ok, Ortex.Model.t()}
  def init(_type, model_name, [_defn_options]) do
    {:ok, {model, _tokenizer}} = Cache.fetch(model_name)
    {:ok, model}
  end

  @impl true
  @spec handle_batch(Nx.Batch.t(), non_neg_integer(), Ortex.Model.t()) ::
          {:execute, (-> {term(), term()}), Ortex.Model.t()}
  def handle_batch(batch, _partition, model) do
    {ids, mask, types} = Nx.Defn.jit_apply(&Function.identity/1, [batch])

    # Copy mask to BinaryBackend before Ortex.run consumes the EXLA buffers
    mask_binary = Nx.backend_transfer(Nx.backend_copy(mask), Nx.BinaryBackend)

    hidden =
      case Ortex.run(model, {ids, mask, types}) do
        {h} -> h
        {h, _} -> h
        {h, _, _} -> h
      end

    hidden = Nx.backend_transfer(hidden, Nx.BinaryBackend)

    # Return {hidden_state, attention_mask} as an Nx container.
    # Nx.Serving slices both along axis 0 per caller.
    {:execute, fn -> {{hidden, mask_binary}, :done} end, model}
  end

  # ── private helpers ───────────────────────────────────────────────────────

  defp build_tensor_batch(encodings) do
    ids_list = Enum.map(encodings, &Tokenizers.Encoding.get_ids/1)
    mask_list = Enum.map(encodings, &Tokenizers.Encoding.get_attention_mask/1)
    type_list = Enum.map(encodings, &Tokenizers.Encoding.get_type_ids/1)

    ids = Nx.tensor(ids_list, type: :s64)
    mask = Nx.tensor(mask_list, type: :s64)
    types = Nx.tensor(type_list, type: :s64)

    {ids, mask, types}
  end
end
