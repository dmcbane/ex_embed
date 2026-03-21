defmodule ExEmbed.PipelineTest do
  use ExUnit.Case, async: true

  alias ExEmbed.Pipeline

  describe "embed/3 output properties" do
    @tag :requires_model
    test "output vectors are L2-normalized to unit length" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      {:ok, tensor} = Pipeline.embed(["hello world"], model, tokenizer)

      assert Nx.shape(tensor) == {1, 384}

      norm = tensor |> Nx.LinAlg.norm(axes: [-1]) |> Nx.to_flat_list() |> hd()
      assert_in_delta norm, 1.0, 0.001
    end

    @tag :requires_model
    test "all rows are L2-normalized in a batch" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      {:ok, tensor} = Pipeline.embed(["alpha", "bravo", "charlie"], model, tokenizer)

      norms = tensor |> Nx.LinAlg.norm(axes: [-1]) |> Nx.to_flat_list()

      for norm <- norms do
        assert_in_delta norm, 1.0, 0.001
      end
    end

    @tag :requires_model
    test "embedding two identical texts produces identical vectors" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")

      text = "the quick brown fox"
      {:ok, tensor} = Pipeline.embed([text, text], model, tokenizer)
      assert Nx.shape(tensor) == {2, 384}

      [v1, v2] = Nx.to_batched(tensor, 1) |> Enum.to_list()
      diff = v1 |> Nx.subtract(v2) |> Nx.abs() |> Nx.reduce_max() |> Nx.to_number()
      assert diff < 0.001
    end

    @tag :requires_model
    test "different texts produce different vectors" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      {:ok, tensor} = Pipeline.embed(["cats are great", "quantum mechanics"], model, tokenizer)

      [v1, v2] = Nx.to_batched(tensor, 1) |> Enum.to_list()
      diff = v1 |> Nx.subtract(v2) |> Nx.abs() |> Nx.reduce_max() |> Nx.to_number()
      assert diff > 0.01
    end
  end

  describe "embed/3 edge cases" do
    @tag :requires_model
    test "empty string produces a valid embedding" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      {:ok, tensor} = Pipeline.embed([""], model, tokenizer)

      assert {1, 384} = Nx.shape(tensor)
      norm = tensor |> Nx.LinAlg.norm(axes: [-1]) |> Nx.to_flat_list() |> hd()
      assert_in_delta norm, 1.0, 0.001
    end

    @tag :requires_model
    test "empty list returns a clear error" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      assert {:error, :empty_input} = Pipeline.embed([], model, tokenizer)
    end

    @tag :requires_model
    test "invalid UTF-8 returns an error" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      # Invalid UTF-8 byte sequence
      assert {:error, :invalid_utf8} = Pipeline.embed([<<0xFF, 0xFE>>], model, tokenizer)
    end

    @tag :requires_model
    test "unicode and emoji text does not crash" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      {:ok, tensor} = Pipeline.embed(["Hello 🌍 résumé naïve 日本語"], model, tokenizer)
      assert {1, 384} = Nx.shape(tensor)
    end

    @tag :requires_model
    test "very long text is truncated to model max tokens and produces valid embedding" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      long_text = String.duplicate("word ", 2000)
      {:ok, tensor} = Pipeline.embed([long_text], model, tokenizer)
      assert {1, 384} = Nx.shape(tensor)

      norm = tensor |> Nx.LinAlg.norm(axes: [-1]) |> Nx.to_flat_list() |> hd()
      assert_in_delta norm, 1.0, 0.001
    end

    @tag :requires_model
    test "mixed-length texts in a batch are padded correctly" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      texts = ["hi", "this is a somewhat longer sentence with more tokens"]
      {:ok, tensor} = Pipeline.embed(texts, model, tokenizer)
      assert {2, 384} = Nx.shape(tensor)

      # Both rows should still be properly normalized
      norms = tensor |> Nx.LinAlg.norm(axes: [-1]) |> Nx.to_flat_list()
      for norm <- norms, do: assert_in_delta(norm, 1.0, 0.001)
    end
  end

  describe "embed_one/3" do
    @tag :requires_model
    test "returns {1, dim} shaped tensor" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      {:ok, tensor} = Pipeline.embed_one("hello", model, tokenizer)
      assert {1, 384} = Nx.shape(tensor)
    end

    @tag :requires_model
    test "produces same result as embed/3 with single-element list" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      {:ok, t1} = Pipeline.embed_one("test sentence", model, tokenizer)
      {:ok, t2} = Pipeline.embed(["test sentence"], model, tokenizer)

      diff = t1 |> Nx.subtract(t2) |> Nx.abs() |> Nx.reduce_max() |> Nx.to_number()
      assert diff == 0.0
    end
  end

  describe "semantic similarity" do
    @tag :requires_model
    test "related texts have higher cosine similarity than unrelated" do
      {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")

      {:ok, tensor} =
        Pipeline.embed(
          [
            "a cat sitting on a mat",
            "a kitten resting on a rug",
            "stock market crash in 2008"
          ],
          model,
          tokenizer
        )

      [v_cat, v_kitten, v_stock] = Nx.to_batched(tensor, 1) |> Enum.to_list()

      # Cosine similarity (vectors are already L2-normalized, so dot product = cosine sim)
      sim_related = Nx.dot(v_cat, [1], v_kitten, [1]) |> Nx.squeeze() |> Nx.to_number()
      sim_unrelated = Nx.dot(v_cat, [1], v_stock, [1]) |> Nx.squeeze() |> Nx.to_number()

      assert sim_related > sim_unrelated
    end
  end
end
