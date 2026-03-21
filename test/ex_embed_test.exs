defmodule ExEmbedTest do
  use ExUnit.Case

  describe "embed/2" do
    test "returns {:error, :not_found} for unknown model" do
      assert {:error, :not_found} = ExEmbed.embed("hello", model: "fake/nonexistent-xyz")
    end

    @tag :requires_model
    test "embeds a single string" do
      assert {:ok, tensor} = ExEmbed.embed("hello world")
      assert {1, 384} = Nx.shape(tensor)
    end

    @tag :requires_model
    test "embeds a list of strings" do
      assert {:ok, tensor} = ExEmbed.embed(["one", "two", "three"])
      assert {3, 384} = Nx.shape(tensor)
    end

    @tag :requires_model
    test "uses default model when no :model option given" do
      assert {:ok, tensor} = ExEmbed.embed("test")
      # Default model BAAI/bge-small-en-v1.5 has dim 384
      assert {1, 384} = Nx.shape(tensor)
    end

    @tag :requires_model
    test "accepts :model option to select a specific model" do
      assert {:ok, tensor} = ExEmbed.embed("test", model: "BAAI/bge-small-en-v1.5")
      assert {1, 384} = Nx.shape(tensor)
    end
  end

  describe "embed!/2" do
    test "raises for unknown model" do
      assert_raise RuntimeError, ~r/ExEmbed.embed! failed/, fn ->
        ExEmbed.embed!("hello", model: "fake/nonexistent-xyz")
      end
    end

    @tag :requires_model
    test "returns tensor directly on success" do
      tensor = ExEmbed.embed!("hello world")
      assert {1, 384} = Nx.shape(tensor)
    end
  end

  describe "list_models/0" do
    test "returns a non-empty list of model name strings" do
      models = ExEmbed.list_models()
      assert is_list(models)
      assert length(models) > 0
      assert Enum.all?(models, &is_binary/1)
      assert "BAAI/bge-small-en-v1.5" in models
    end
  end

  describe "preload/1" do
    test "returns {:error, :not_found} for unknown model" do
      assert {:error, :not_found} = ExEmbed.preload("fake/nonexistent-xyz")
    end

    @tag :requires_model
    test "returns :ok for a valid model" do
      assert :ok = ExEmbed.preload("BAAI/bge-small-en-v1.5")
    end
  end

  describe "similarity/2" do
    @tag :requires_model
    test "identical texts have similarity ~1.0" do
      {:ok, t} = ExEmbed.embed(["hello", "hello"])
      [v1, v2] = Nx.to_batched(t, 1) |> Enum.to_list()
      assert_in_delta ExEmbed.similarity(v1, v2), 1.0, 0.001
    end

    @tag :requires_model
    test "unrelated texts have lower similarity" do
      {:ok, t} = ExEmbed.embed(["cat on a mat", "stock market crash"])
      [v1, v2] = Nx.to_batched(t, 1) |> Enum.to_list()
      sim = ExEmbed.similarity(v1, v2)
      assert sim < 0.5
    end

    @tag :requires_model
    test "returns a float between -1.0 and 1.0" do
      {:ok, t} = ExEmbed.embed(["alpha", "beta"])
      [v1, v2] = Nx.to_batched(t, 1) |> Enum.to_list()
      sim = ExEmbed.similarity(v1, v2)
      assert is_float(sim)
      assert sim >= -1.0 and sim <= 1.0
    end

    test "works with raw tensors (not just embeddings)" do
      v1 = Nx.tensor([1.0, 0.0, 0.0])
      v2 = Nx.tensor([0.0, 1.0, 0.0])
      assert_in_delta ExEmbed.similarity(v1, v2), 0.0, 0.001
    end

    test "orthogonal unit vectors have similarity 0" do
      v1 = Nx.tensor([1.0, 0.0])
      v2 = Nx.tensor([0.0, 1.0])
      assert_in_delta ExEmbed.similarity(v1, v2), 0.0, 0.001
    end
  end

  describe "model_info/1" do
    test "returns metadata for a known model" do
      assert {:ok, info} = ExEmbed.model_info("BAAI/bge-small-en-v1.5")
      assert info.dim == 384
      assert is_binary(info.hf_repo)
    end

    test "returns error for unknown model" do
      assert {:error, :not_found} = ExEmbed.model_info("fake/nonexistent-xyz")
    end

    test "includes all expected fields" do
      {:ok, info} = ExEmbed.model_info("BAAI/bge-small-en-v1.5")
      assert Map.has_key?(info, :name)
      assert Map.has_key?(info, :dim)
      assert Map.has_key?(info, :hf_repo)
      assert Map.has_key?(info, :model_file)
      assert Map.has_key?(info, :additional_files)
      assert Map.has_key?(info, :size_gb)
    end

    test "dim matches actual model output without loading" do
      {:ok, info} = ExEmbed.model_info("BAAI/bge-small-en-v1.5")
      assert info.dim == 384
    end
  end

  describe "health_check/1" do
    @tag :requires_model
    test "returns :ok when model is working" do
      assert :ok = ExEmbed.health_check()
    end

    test "returns error for unknown model" do
      assert {:error, _} = ExEmbed.health_check("fake/nonexistent-xyz")
    end
  end

  describe "available?/1" do
    test "returns false for unknown model" do
      refute ExEmbed.available?("fake/nonexistent-xyz")
    end

    @tag :requires_model
    test "returns true after model is loaded" do
      {:ok, _} = ExEmbed.embed("test")
      assert ExEmbed.available?()
    end
  end
end
