defmodule ExEmbed.Registry do
  @moduledoc """
  Curated registry of known-good quantized ONNX embedding models,
  translated from FastEmbed's model list. HuggingFace is the source
  of truth for actual file contents; this registry provides metadata
  for discovery and download planning.

  Run `mix ex_embed.check_registry` to diff against FastEmbed upstream.
  """

  @models_file Path.join(:code.priv_dir(:ex_embed), "registry/models.json")
  @external_resource @models_file

  @models @models_file
          |> File.read!()
          |> Jason.decode!(keys: :atoms)
          |> Map.new(fn m -> {m.name, m} end)

  @doc "Return metadata map for a model by name, or `{:error, :not_found}`."
  @spec get(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get(name) do
    case Map.fetch(@models, name) do
      {:ok, model} -> {:ok, model}
      :error -> {:error, :not_found}
    end
  end

  @doc "Return all registered model names."
  @spec list() :: [String.t()]
  def list, do: Map.keys(@models)

  @doc "Return all model metadata maps."
  @spec all() :: [map()]
  def all, do: Map.values(@models)

  @doc "Return the default model name."
  @spec default() :: String.t()
  def default, do: "BAAI/bge-small-en-v1.5"
end
