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
end
