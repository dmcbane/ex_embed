defmodule ExEmbed.Pipeline do
  @moduledoc """
  Core embedding pipeline: tokenize → infer (ONNX) → mean pool → L2 normalize.

  Operates on pre-loaded model/tokenizer structs. For managed loading with
  caching, use `ExEmbed.Cache` or `ExEmbed.Serving`.
  """

  import Nx.Defn

  @doc """
  Embed a list of texts using a loaded model and tokenizer.
  Returns `{:ok, tensor}` where tensor shape is `{n, dim}`.
  """
  @spec embed([String.t()], Ortex.Model.t(), Tokenizers.Tokenizer.t()) ::
          {:ok, Nx.Tensor.t()} | {:error, term()}
  def embed([], _model, _tokenizer), do: {:error, :empty_input}

  def embed(texts, model, tokenizer) when is_list(texts) do
    with {:ok, {ids, attention_mask, token_type_ids}} <- tokenize_batch(texts, tokenizer),
         {:ok, hidden_state} <- run_inference(model, ids, attention_mask, token_type_ids) do
      embedding = mean_pool_and_normalize(hidden_state, attention_mask)
      {:ok, embedding}
    end
  end

  @doc "Embed a single text. Returns `{:ok, tensor}` with shape `{1, dim}`."
  @spec embed_one(String.t(), Ortex.Model.t(), Tokenizers.Tokenizer.t()) ::
          {:ok, Nx.Tensor.t()} | {:error, term()}
  def embed_one(text, model, tokenizer) when is_binary(text) do
    embed([text], model, tokenizer)
  end

  # ── private ────────────────────────────────────────────────────────────────

  defp tokenize_batch(texts, tokenizer) do
    with {:ok, encodings} <- Tokenizers.Tokenizer.encode_batch(tokenizer, texts, add_special_tokens: true) do
      ids_list = Enum.map(encodings, &Tokenizers.Encoding.get_ids/1)
      mask_list = Enum.map(encodings, &Tokenizers.Encoding.get_attention_mask/1)
      type_list = Enum.map(encodings, &Tokenizers.Encoding.get_type_ids/1)

      ids_tensor = Nx.tensor(ids_list, type: :s64)
      mask_tensor = Nx.tensor(mask_list, type: :s64)
      type_tensor = Nx.tensor(type_list, type: :s64)

      {:ok, {ids_tensor, mask_tensor, type_tensor}}
    end
  rescue
    e -> {:error, {:tokenization_failed, e}}
  end

  defp run_inference(model, ids, attention_mask, token_type_ids) do
    try do
      result = Ortex.run(model, {ids, attention_mask, token_type_ids})

      hidden =
        case result do
          {h} -> h
          {h, _} -> h
          {h, _, _} -> h
          other -> raise "Unexpected ONNX output shape: #{inspect(other)}"
        end

      # Transfer from Ortex backend to default Nx backend for math ops
      {:ok, Nx.backend_transfer(hidden)}
    rescue
      e -> {:error, {:inference_failed, e}}
    end
  end

  @doc """
  Mean pool hidden states using attention mask, then L2 normalize.

  Accelerated via EXLA when configured (`config :nx, default_defn_options: [compiler: EXLA]`).
  """
  defn mean_pool_and_normalize(hidden_state, attention_mask) do
    # Expand mask: {batch, seq} → {batch, seq, 1}
    mask_expanded = Nx.new_axis(attention_mask, -1) |> Nx.as_type(:f32)

    # Mask out padding token embeddings
    masked = Nx.multiply(hidden_state, mask_expanded)

    # Sum over sequence dimension, divide by actual token count
    sum = Nx.sum(masked, axes: [1])
    counts = Nx.sum(mask_expanded, axes: [1]) |> Nx.max(1.0e-9)
    pooled = Nx.divide(sum, counts)

    # L2 normalize
    norm = Nx.pow(pooled, 2) |> Nx.sum(axes: [-1], keep_axes: true) |> Nx.sqrt() |> Nx.max(1.0e-12)
    Nx.divide(pooled, norm)
  end
end
