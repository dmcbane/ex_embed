# ExEmbed

Elixir-native text embeddings via [Ortex](https://github.com/elixir-nx/ortex) (ONNX Runtime)
and [Tokenizers](https://github.com/elixir-nx/tokenizers), with a
[FastEmbed](https://github.com/qdrant/fastembed)-compatible model registry backed by HuggingFace.

No Python. No PyTorch. Runs entirely inside the BEAM.

## Features

- **Tier 1** — Raw ONNX pipeline: tokenize → infer → mean pool → L2 normalize
- **Tier 2** — `Nx.Serving` wrapper for batching and backpressure
- **Tier 3** — B+C hybrid registry: vendored metadata + HuggingFace file resolution

## Installation

```elixir
def deps do
  [{:ex_embed, "~> 0.1"}]
end
```

## Quick start

```elixir
# Embed a single text (downloads model on first use)
{:ok, tensor} = ExEmbed.embed("Hello, world!")
# => {:ok, #Nx.Tensor<f32[1][384]>}

# Embed a batch with a specific model
{:ok, tensor} = ExEmbed.embed(["text one", "text two"], model: "BAAI/bge-base-en-v1.5")

# List available models
ExEmbed.list_models()
```

## Production: Nx.Serving

```elixir
# In your supervision tree:
{Nx.Serving,
  serving: ExEmbed.Serving.new("BAAI/bge-small-en-v1.5"),
  name: MyApp.EmbeddingServing,
  batch_size: 32,
  batch_timeout: 100}

# At call time (e.g. on note save in LiveView):
{:ok, vec} = Nx.Serving.run(MyApp.EmbeddingServing, note.content)
```

## Mix tasks

```bash
mix ex_embed.list                           # show all registered models
mix ex_embed.download bge-small-en-v1.5    # prefetch a model
mix ex_embed.check_registry                # diff against FastEmbed upstream
```

## Supported models

| Model | Dim | Size | Notes |
|---|---|---|---|
| BAAI/bge-small-en-v1.5 *(default)* | 384 | 67 MB | Fast, English |
| BAAI/bge-base-en-v1.5 | 768 | 210 MB | Balanced, English |
| BAAI/bge-large-en-v1.5 | 1024 | 590 MB | High quality, English |
| BAAI/bge-m3 | 1024 | 1.2 GB | Multilingual, 100+ langs |
| sentence-transformers/all-MiniLM-L6-v2 | 384 | 90 MB | Popular general-purpose |
| nomic-ai/nomic-embed-text-v1.5 | 768 | 130 MB | Long context (8192 tokens) |
| intfloat/multilingual-e5-small | 384 | 120 MB | Multilingual |
| intfloat/multilingual-e5-base | 768 | 270 MB | Multilingual |
| mixedbread-ai/mxbai-embed-large-v1 | 1024 | 560 MB | Strong MTEB scores |
| Alibaba-NLP/gte-base-en-v1.5 | 768 | 210 MB | Strong English |

Run `mix ex_embed.check_registry` to check for new models in the FastEmbed upstream.

## Configuration

```elixir
# config/config.exs
config :ex_embed,
  cache_dir: "/path/to/model/cache"  # default: ~/.cache/ex_embed
```

## License

Apache 2.0
