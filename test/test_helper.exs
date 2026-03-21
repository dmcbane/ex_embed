# Exclude model-dependent tests when the default model is not cached locally.
default_model_repo = "qdrant/bge-small-en-v1.5-onnx-q"

cache_dir =
  Application.get_env(:ex_embed, :cache_dir, Path.join(System.user_home!(), ".cache/ex_embed"))

model_available? =
  Path.join(cache_dir, Path.join(default_model_repo, "model_optimized.onnx"))
  |> File.exists?()

exclude = if model_available?, do: [], else: [:requires_model]
# Network tests are excluded by default; opt in with: mix test --include requires_network
exclude = [:requires_network | exclude]

ExUnit.start(exclude: exclude)
