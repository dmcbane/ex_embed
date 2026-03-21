defmodule ExEmbed.Pipeline do
  @moduledoc """
  Core embedding pipeline: tokenize → infer (ONNX) → mean pool → L2 normalize.

  Operates on pre-loaded model/tokenizer structs. For managed loading with
  caching, use `ExEmbed.Cache` or `ExEmbed.Serving`.
  """

  @doc """
  Embed a list of texts using a loaded model and tokenizer.
  Returns `{:ok, tensor}` where tensor shape is `{n, dim}`.
  """
  @spec embed([String.t()], Ortex.Model.t(), Tokenizers.Tokenizer.t()) ::
          {:ok, Nx.Tensor.t()} | {:error, term()}
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
    try do
      encodings =
        Enum.map(texts, fn text ->
          {:ok, enc} = Tokenizers.Tokenizer.encode(tokenizer, text, add_special_tokens: true)
          enc
        end)

      max_len =
        encodings
        |> Enum.map(&length(Tokenizers.Encoding.get_ids(&1)))
        |> Enum.max()

      # Pad all sequences to max_len
      {ids_list, mask_list, type_list} =
        Enum.reduce(encodings, {[], [], []}, fn enc, {ids_acc, mask_acc, type_acc} ->
          ids = Tokenizers.Encoding.get_ids(enc)
          mask = Tokenizers.Encoding.get_attention_mask(enc)
          types = Tokenizers.Encoding.get_type_ids(enc)

          pad_len = max_len - length(ids)
          ids_padded = ids ++ List.duplicate(0, pad_len)
          mask_padded = mask ++ List.duplicate(0, pad_len)
          types_padded = types ++ List.duplicate(0, pad_len)

          {[ids_padded | ids_acc], [mask_padded | mask_acc], [types_padded | type_acc]}
        end)

      ids_tensor = ids_list |> Enum.reverse() |> Nx.tensor(type: :s64)
      mask_tensor = mask_list |> Enum.reverse() |> Nx.tensor(type: :s64)
      type_tensor = type_list |> Enum.reverse() |> Nx.tensor(type: :s64)

      {:ok, {ids_tensor, mask_tensor, type_tensor}}
    rescue
      e -> {:error, {:tokenization_failed, e}}
    end
  end

  defp run_inference(model, ids, attention_mask, token_type_ids) do
    try do
      result = Ortex.run(model, {ids, attention_mask, token_type_ids})

      hidden =
        case result do
          {:ok, %{"last_hidden_state" => h}} -> h
          {:ok, {h, _}} -> h
          {:ok, [h | _]} -> h
          other -> raise "Unexpected ONNX output shape: #{inspect(other)}"
        end

      {:ok, hidden}
    rescue
      e -> {:error, {:inference_failed, e}}
    end
  end

  defp mean_pool_and_normalize(hidden_state, attention_mask) do
    # Expand mask: {batch, seq} → {batch, seq, 1}
    mask_expanded = Nx.new_axis(attention_mask, -1) |> Nx.as_type(:f32)

    # Mask out padding token embeddings
    masked = Nx.multiply(hidden_state, mask_expanded)

    # Sum over sequence dimension, divide by actual token count
    sum = Nx.sum(masked, axes: [1])
    counts = Nx.sum(mask_expanded, axes: [1]) |> Nx.clip(1.0e-9, :infinity)
    pooled = Nx.divide(sum, counts)

    # L2 normalize
    norm = Nx.LinAlg.norm(pooled, axes: [-1], keep_axes: true) |> Nx.clip(1.0e-12, :infinity)
    Nx.divide(pooled, norm)
  end
end
