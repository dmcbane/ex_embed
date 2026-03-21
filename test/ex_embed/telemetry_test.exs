defmodule ExEmbed.TelemetryTest do
  use ExUnit.Case

  describe "embed telemetry events" do
    @tag :requires_model
    test "emits [:ex_embed, :embed, :start] and [:ex_embed, :embed, :stop]" do
      ref = make_ref()
      pid = self()

      :telemetry.attach_many(
        "test-embed-#{inspect(ref)}",
        [[:ex_embed, :embed, :start], [:ex_embed, :embed, :stop]],
        fn event, measurements, metadata, _ ->
          send(pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-embed-#{inspect(ref)}") end)

      {:ok, _tensor} = ExEmbed.embed("hello telemetry")

      assert_receive {:telemetry, [:ex_embed, :embed, :start], %{system_time: _}, %{model: _}}
      assert_receive {:telemetry, [:ex_embed, :embed, :stop], %{duration: duration}, %{model: _}}
      assert is_integer(duration) and duration > 0
    end
  end

  describe "cache telemetry events" do
    @tag :requires_model
    test "emits cache hit event on second fetch" do
      ref = make_ref()
      pid = self()

      # Ensure model is loaded first
      {:ok, _} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")

      :telemetry.attach(
        "test-cache-#{inspect(ref)}",
        [:ex_embed, :cache, :hit],
        fn event, measurements, metadata, _ ->
          send(pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-cache-#{inspect(ref)}") end)

      {:ok, _} = ExEmbed.Cache.fetch("BAAI/bge-small-en-v1.5")

      assert_receive {:telemetry, [:ex_embed, :cache, :hit], _, %{model: "BAAI/bge-small-en-v1.5"}}
    end
  end
end
