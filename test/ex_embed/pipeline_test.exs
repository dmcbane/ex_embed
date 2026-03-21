defmodule ExEmbed.PipelineTest do
  use ExUnit.Case, async: true

  alias ExEmbed.Pipeline

  describe "mean_pool_and_normalize (via embed)" do
    test "output vectors are L2-normalized to unit length" do
      # This test uses a real model if available, skips otherwise
      model_name = "BAAI/bge-small-en-v1.5"

      case ExEmbed.Cache.fetch(model_name) do
        {:ok, {model, tokenizer}} ->
          {:ok, tensor} = Pipeline.embed(["hello world"], model, tokenizer)
          # shape {1, 384}
          assert Nx.shape(tensor) == {1, 384}
          # L2 norm of each row should be ~1.0
          norm = tensor |> Nx.LinAlg.norm(axes: [-1]) |> Nx.to_flat_list() |> hd()
          assert_in_delta norm, 1.0, 0.001

        {:error, _} ->
          IO.puts("Skipping: model not available in CI")
      end
    end

    test "embedding two identical texts produces identical vectors" do
      model_name = "BAAI/bge-small-en-v1.5"

      case ExEmbed.Cache.fetch(model_name) do
        {:ok, {model, tokenizer}} ->
          text = "the quick brown fox"
          {:ok, tensor} = Pipeline.embed([text, text], model, tokenizer)
          assert Nx.shape(tensor) == {2, 384}

          [v1, v2] = Nx.to_batched(tensor, 1) |> Enum.to_list()
          diff = v1 |> Nx.subtract(v2) |> Nx.abs() |> Nx.reduce_max() |> Nx.to_number()
          assert diff < 0.001

        {:error, _} ->
          IO.puts("Skipping: model not available in CI")
      end
    end
  end
end
