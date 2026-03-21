# Changelog

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## [0.3.0](https://github.com/dmcbane/ex_embed/compare/v0.2.3...v0.3.0) (2026-03-21)

### New Features

* Atomic downloads with .tmp file + rename pattern
* Exponential backoff retry (3 attempts) for network errors
* `ExEmbed.similarity/2` — cosine similarity between embeddings
* `ExEmbed.model_info/1` — get model metadata without loading
* `ExEmbed.health_check/1` — verify full pipeline end-to-end
* Telemetry events for embed, cache hit/miss/load
* `mix ex_embed.cache_list` and `mix ex_embed.cache_clean` tasks
* Configurable truncation direction (`:left` or `:right`)
* Model version pinning via optional `revision` field in registry
* UTF-8 input validation before tokenization

### Refactoring

* Structured logging with keyword metadata

### Tests

* 114 total tests covering all features, security, and edge cases

## [0.2.3](https://github.com/dmcbane/ex_embed/compare/v0.2.2...v0.2.3) (2026-03-21)

### Bug Fixes

* Fix checksum key mismatch (atom vs string) that silently skipped verification

### Tests

* 18 security regression tests covering OWASP findings

## [0.2.2](https://github.com/dmcbane/ex_embed/compare/v0.2.1...v0.2.2) (2026-03-21)

### Security

* LRU cache eviction with configurable `max_models` limit
* Auto-create cache_dir on first use
* System paths removed from info/warning logs

## [0.2.1](https://github.com/dmcbane/ex_embed/compare/v0.2.0...v0.2.1) (2026-03-21)

### Security

* Path traversal protection in Downloader and HFClient
* SHA256 checksum verification for downloaded model files
* Error messages redacted — generic atoms to callers, details at :debug only
* HF_TOKEN leak prevention — errors wrapped without exposing headers
* URL encoding for repo/filename parameters
* Network timeouts (30s API, 10min downloads)

## [0.2.0](https://github.com/dmcbane/ex_embed/compare/v0.1.1...v0.2.0) (2026-03-21)

### New Features

* EXLA optional backend for JIT-compiled pooling/normalization
* Proper `@behaviour Nx.Serving` with init/handle_batch callbacks
* Graceful degradation — Serving.start_link returns :ignore on failure
* `ExEmbed.available?/1` health check API
* Optional supervised Serving via `config :ex_embed, serving: [...]`

### Refactoring

* Replace manual tokenization with Tokenizers.encode_batch + built-in truncation/padding
* Pipeline.mean_pool_and_normalize converted to defn

## [0.1.1](https://github.com/dmcbane/ex_embed/compare/v0.1.0...v0.1.1) (2026-03-21)

### Bug Fixes

* Fix Ortex.load/1 return value (bare struct, not {:ok, _})
* Fix Ortex.run/2 output patterns (tuple of tensors, not {:ok, _})
* Add Nx.backend_transfer after ONNX inference
* Fix Pipeline.embed/3 empty list handling
* Add token truncation at 512
* Fix Serving to accept string input
* Fix check_registry task to raise on failure

### Tests

* 52 tests covering all major modules

## [0.1.0](https://github.com/dmcbane/ex_embed/releases/tag/v0.1.0) (2026-03-21)

### New Features

* Initial scaffold with three-tier architecture
* Pure Pipeline: tokenize → ONNX inference → mean pool → L2 normalize
* Cache GenServer for lazy model loading
* B+C Hybrid Registry with vendored metadata + HuggingFace resolution
* 10 curated quantized ONNX embedding models
* Mix tasks: list, download, check_registry
