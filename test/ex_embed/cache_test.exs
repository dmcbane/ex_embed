defmodule ExEmbed.CacheTest do
  use ExUnit.Case

  describe "GenServer state" do
    test "loaded/0 returns a list" do
      loaded = ExEmbed.Cache.loaded()
      assert is_list(loaded)
      assert Enum.all?(loaded, &is_binary/1)
    end

    test "fetch returns {:error, :not_found} for unregistered model" do
      assert {:error, :not_found} = ExEmbed.Cache.fetch("fake/nonexistent-model-xyz")
    end
  end

  describe "model loading" do
    @tag :requires_model
    test "fetch loads and returns {model, tokenizer} tuple" do
      assert {:ok, {model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      assert %Ortex.Model{} = model
      assert tokenizer != nil
    end

    @tag :requires_model
    test "tokenizer has truncation and padding configured" do
      {:ok, {_model, tokenizer}} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      # Verify truncation/padding work by encoding a very long text — should not exceed 512 tokens
      {:ok, enc} = Tokenizers.Tokenizer.encode(tokenizer, String.duplicate("word ", 2000))
      assert length(Tokenizers.Encoding.get_ids(enc)) <= 512
    end

    @tag :requires_model
    test "loaded/0 includes model name after fetch" do
      {:ok, _} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      assert "BAAI/bge-small-en-v1.5" in ExEmbed.Cache.loaded()
    end

    @tag :requires_model
    test "second fetch returns cached result without reloading" do
      {:ok, result1} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      {:ok, result2} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      # Same model/tokenizer references
      assert result1 == result2
    end

    @tag :requires_model
    test "concurrent fetches for the same model all succeed" do
      tasks =
        for _ <- 1..5 do
          Task.async(fn -> ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5") end)
        end

      results = Task.await_many(tasks, :timer.minutes(2))
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end
  end

  describe "available?/1" do
    test "returns false for model not yet loaded" do
      refute ExEmbed.Cache.available?("definitely/not-loaded-xyz")
    end

    @tag :requires_model
    test "returns true after model is fetched" do
      {:ok, _} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")
      assert ExEmbed.Cache.available?("BAAI/bge-small-en-v1.5")
    end
  end

  describe "preload/1" do
    test "returns {:error, :not_found} for unknown model" do
      assert {:error, :not_found} = ExEmbed.Cache.preload("fake/nonexistent-model-xyz")
    end

    @tag :requires_model
    test "returns :ok for valid model" do
      assert :ok = ExEmbed.Cache.preload("BAAI/bge-small-en-v1.5")
    end
  end
end
