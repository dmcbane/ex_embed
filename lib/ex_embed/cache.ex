defmodule ExEmbed.Cache do
  @moduledoc """
  GenServer that holds loaded models keyed by name.
  Lazy-loads on first use: downloads if necessary, then loads into memory.

  The process is started automatically by `ExEmbed.Application`.

  Configure `config :ex_embed, max_models: 10` to limit the number of
  models held in memory (default: 10). Least-recently-used models are
  evicted when the limit is reached.
  """

  use GenServer
  alias ExEmbed.{Downloader, Registry}
  require Logger

  @default_max_models 10

  # State: %{models: %{name => {entry, last_used_monotonic}}}

  # ── public API ─────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Return `{model, tokenizer}` for `model_name`, loading/downloading as needed.
  """
  @spec fetch(String.t()) :: {:ok, {Ortex.Model.t(), Tokenizers.Tokenizer.t()}} | {:error, term()}
  def fetch(model_name) do
    GenServer.call(__MODULE__, {:fetch, model_name}, :timer.minutes(5))
  end

  @doc "Preload a model into the cache (useful at startup for known-hot models)."
  @spec preload(String.t()) :: :ok | {:error, term()}
  def preload(model_name) do
    case fetch(model_name) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc "Check if a model is already loaded in the cache (does not trigger loading)."
  @spec available?(String.t()) :: boolean()
  def available?(model_name \\ ExEmbed.Registry.default()) do
    GenServer.call(__MODULE__, {:available?, model_name})
  end

  @doc "List currently loaded model names."
  @spec loaded() :: [String.t()]
  def loaded do
    GenServer.call(__MODULE__, :loaded)
  end

  # ── callbacks ──────────────────────────────────────────────────────────────

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call({:fetch, model_name}, _from, state) do
    case Map.fetch(state, model_name) do
      {:ok, {entry, _last_used}} ->
        # Update last-used timestamp
        {:reply, {:ok, entry}, Map.put(state, model_name, {entry, now()})}

      :error ->
        case load_model(model_name) do
          {:ok, entry} ->
            state = maybe_evict(state)
            {:reply, {:ok, entry}, Map.put(state, model_name, {entry, now()})}

          {:error, _} = err ->
            {:reply, err, state}
        end
    end
  end

  @impl true
  def handle_call({:available?, model_name}, _from, state) do
    {:reply, Map.has_key?(state, model_name), state}
  end

  @impl true
  def handle_call(:loaded, _from, state) do
    {:reply, Map.keys(state), state}
  end

  # ── private ────────────────────────────────────────────────────────────────

  defp load_model(model_name) do
    Logger.debug("[ExEmbed] Loading model: #{model_name}")

    with {:ok, meta} <- Registry.get(model_name),
         {:ok, cache_path} <- Downloader.ensure(model_name) do
      model_path = Path.join(cache_path, meta.model_file)
      tokenizer_path = Path.join(cache_path, "tokenizer.json")

      try do
        model = Ortex.load(model_path)

        with {:ok, tokenizer} <- Tokenizers.Tokenizer.from_file(tokenizer_path) do
          tokenizer = configure_tokenizer(tokenizer)
          Logger.info("[ExEmbed] Model ready: #{model_name} (#{meta.dim}d)")
          {:ok, {model, tokenizer}}
        end
      rescue
        e ->
          Logger.debug("[ExEmbed] Model load failed: #{Exception.message(e)}")
          {:error, :model_load_failed}
      end
    end
  end

  defp maybe_evict(state) do
    max = Application.get_env(:ex_embed, :max_models, @default_max_models)

    if map_size(state) >= max do
      # Evict least-recently-used model
      {lru_name, _} = Enum.min_by(state, fn {_name, {_entry, last_used}} -> last_used end)
      Logger.info("[ExEmbed] Evicting LRU model: #{lru_name}")
      Map.delete(state, lru_name)
    else
      state
    end
  end

  defp now, do: System.monotonic_time(:millisecond)

  defp configure_tokenizer(tokenizer) do
    tokenizer
    |> Tokenizers.Tokenizer.set_truncation(max_length: 512)
    |> Tokenizers.Tokenizer.set_padding(strategy: :batch_longest)
  end
end
