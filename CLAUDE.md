# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ExEmbed is an Elixir library for local text embeddings using ONNX Runtime. It provides a three-tier architecture for embedding text without external API calls, using quantized models from HuggingFace.

## Common Commands

```bash
# Install dependencies
mix deps.get

# Compile
mix compile

# Run all tests
mix test

# Run a single test file
mix test test/ex_embed/registry_test.exs

# Run a specific test by line number
mix test test/ex_embed/pipeline_test.exs:10

# Type checking
mix dialyzer

# Generate docs
mix docs

# List registered models
mix ex_embed.list

# Download a model to local cache
mix ex_embed.download bge-small-en-v1.5

# Check registry against FastEmbed upstream
mix ex_embed.check_registry
```

Note: Pipeline tests download models from HuggingFace on first run. Registry tests are fast and self-contained.

## Architecture

### Three-Tier Design

**Tier 1 — Pure Pipeline (`ExEmbed.Pipeline`):** Stateless embedding function. Takes texts + loaded model/tokenizer, returns normalized embedding tensors. Flow: tokenize → batch & pad → ONNX inference → mean pool → L2 normalize.

**Tier 2 — Stateful Cache & Serving (`ExEmbed.Cache`, `ExEmbed.Serving`):** Cache is a GenServer that lazy-loads and memoizes models. Serving wraps Nx.Serving for batched inference with backpressure. The Application supervisor starts Cache automatically.

**Tier 3 — B+C Hybrid Registry (`ExEmbed.Registry`, `ExEmbed.Downloader`, `ExEmbed.HFClient`):**
- **B (build-time):** `priv/registry/models.json` is loaded into `@models` module attribute at compile time — fast lookup, works offline.
- **C (runtime):** `HFClient` resolves download URLs and fetches metadata from HuggingFace API. `Downloader` manages the local file cache at `~/.cache/ex_embed/`.

### Request Flow

`ExEmbed.embed/2` → `Cache.fetch/1` (GenServer) → `Downloader.ensure/1` (download if missing) → `Ortex.load` + `Tokenizers.from_file` → `Pipeline.embed/3` (tokenize → infer → pool → normalize)

### Public API

The main entry point is `ExEmbed` (lib/ex_embed/ex_embed.ex) which exposes `embed/2`, `embed!/2`, `list_models/0`, and `preload/1`.

### Key Dependencies

- **ortex** — ONNX Runtime bindings (`Ortex.load/1`, `Ortex.run/2`)
- **tokenizers** — HuggingFace tokenizer bindings
- **nx** — Tensor operations (padding, pooling, normalization)
- **req** — HTTP client for HuggingFace downloads

### Configuration

```elixir
config :ex_embed, cache_dir: "/custom/path"  # default: ~/.cache/ex_embed
```

The `HF_TOKEN` env var is respected for private model access.

## Code Principles

**TEST DRIVEN DEVELOPMENT.** Always write tests before making changes or adding features. Write the failing test first, then implement the code to make it pass. Tag tests that need a real model with `@tag :requires_model` and network-dependent tests with `@tag :requires_network`.

**NEVER SWALLOW ERRORS.** Tests must not silently pass when they skip their assertions — use `@tag` and `ExUnit.configure(exclude: ...)` so skipped tests are visible. In production code, always surface errors explicitly; never match an error branch and silently succeed (e.g., `{:error, _} -> :ok`).

### Model Registry

`priv/registry/models.json` contains 10 curated ONNX models. Each entry has: name, dim, hf_repo, model_file, additional_files, size_gb, license. The default model is `BAAI/bge-small-en-v1.5`. When adding models, update this JSON file — it is compiled into the Registry module attribute.
