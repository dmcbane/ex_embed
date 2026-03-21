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

  describe "inline serving execution" do
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

  describe "start_link/1 and availability" do
    @tag :requires_model
    test "start_link starts a named serving process" do
      pid = start_supervised!({ExEmbed.Serving, name: TestStartLinkServing, batch_timeout: 50})
      assert is_pid(pid)
      assert ExEmbed.Serving.available?(TestStartLinkServing)
    end

    test "start_link returns :ignore for invalid model" do
      assert :ignore = ExEmbed.Serving.start_link(model: "fake/nonexistent-xyz", name: TestBadServing)
    end

    test "available? returns false when serving is not started" do
      refute ExEmbed.Serving.available?(:nonexistent_serving_process)
    end
  end

  describe "process-based serving" do
    @tag :requires_model
    test "works under a supervisor with batched_run" do
      serving = ExEmbed.Serving.new("BAAI/bge-small-en-v1.5")

      start_supervised!(
        {Nx.Serving, serving: serving, name: TestEmbeddingServing, batch_timeout: 50}
      )

      tensor = Nx.Serving.batched_run(TestEmbeddingServing, "hello process")
      assert {1, 384} = Nx.shape(tensor)

      norm = tensor |> Nx.LinAlg.norm(axes: [-1]) |> Nx.to_flat_list() |> hd()
      assert_in_delta norm, 1.0, 0.001
    end

    @tag :requires_model
    test "concurrent requests to process-based serving all succeed" do
      serving = ExEmbed.Serving.new("BAAI/bge-small-en-v1.5")

      start_supervised!(
        {Nx.Serving, serving: serving, name: TestConcurrentServing, batch_timeout: 50}
      )

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            Nx.Serving.batched_run(TestConcurrentServing, "text #{i}")
          end)
        end

      results = Task.await_many(tasks, :timer.minutes(1))

      for tensor <- results do
        assert {1, 384} = Nx.shape(tensor)
      end
    end
  end
end
