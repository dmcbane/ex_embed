defmodule ExEmbed.Cache do
  @moduledoc """
  GenServer that holds loaded models keyed by name.
  Lazy-loads on first use: downloads if necessary, then loads into memory.

  The process is started automatically by `ExEmbed.Application`.
  """

  use GenServer
  alias ExEmbed.{Downloader, Registry}
  require Logger

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
      {:ok, entry} ->
        {:reply, {:ok, entry}, state}

      :error ->
        case load_model(model_name) do
          {:ok, entry} ->
            {:reply, {:ok, entry}, Map.put(state, model_name, entry)}

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
    Logger.info("[ExEmbed] Loading model: #{model_name}")

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

  defp configure_tokenizer(tokenizer) do
    tokenizer
    |> Tokenizers.Tokenizer.set_truncation(max_length: 512)
    |> Tokenizers.Tokenizer.set_padding(strategy: :batch_longest)
  end
end
