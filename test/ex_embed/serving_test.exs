defmodule ExEmbed.ServingTest do
  use ExUnit.Case

  describe "new/1" do
    test "returns an Nx.Serving struct" do
      serving = ExEmbed.Serving.new()
      assert %Nx.Serving{} = serving
    end

    test "accepts a model name argument" do
      serving = ExEmbed.Serving.new("BAAI/bge-small-en-v1.5")
      assert %Nx.Serving{} = serving
    end
  end

  describe "serving execution" do
    @tag :requires_model
    test "embeds a single string" do
      serving = ExEmbed.Serving.new("BAAI/bge-small-en-v1.5")
      tensor = Nx.Serving.run(serving, "hello world")
      assert {1, 384} = Nx.shape(tensor)
    end

    @tag :requires_model
    test "embeds a list of strings" do
      serving = ExEmbed.Serving.new("BAAI/bge-small-en-v1.5")
      tensor = Nx.Serving.run(serving, ["one", "two", "three"])
      assert {3, 384} = Nx.shape(tensor)
    end

    @tag :requires_model
    test "produces L2-normalized output" do
      serving = ExEmbed.Serving.new("BAAI/bge-small-en-v1.5")
      tensor = Nx.Serving.run(serving, "test normalization")

      norm = tensor |> Nx.LinAlg.norm(axes: [-1]) |> Nx.to_flat_list() |> hd()
      assert_in_delta norm, 1.0, 0.001
    end
  end
end
