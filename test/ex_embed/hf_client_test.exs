defmodule ExEmbed.HFClientTest do
  use ExUnit.Case, async: true

  alias ExEmbed.HFClient

  describe "resolve_url/2" do
    test "constructs correct HuggingFace download URL" do
      url = HFClient.resolve_url("BAAI/bge-small-en-v1.5", "model.onnx")
      assert url == "https://huggingface.co/BAAI/bge-small-en-v1.5/resolve/main/model.onnx"
    end

    test "handles nested file paths" do
      url = HFClient.resolve_url("org/repo", "subdir/weights.bin")
      assert url == "https://huggingface.co/org/repo/resolve/main/subdir/weights.bin"
    end

    test "handles repo names with dots and hyphens" do
      url = HFClient.resolve_url("nomic-ai/nomic-embed-text-v1.5", "model_optimized.onnx")
      assert url == "https://huggingface.co/nomic-ai/nomic-embed-text-v1.5/resolve/main/model_optimized.onnx"
    end
  end

  describe "model_info/1" do
    @tag :requires_network
    test "returns metadata for a valid repo" do
      assert {:ok, body} = HFClient.model_info("BAAI/bge-small-en-v1.5")
      assert is_map(body)
    end

    @tag :requires_network
    test "returns error for nonexistent repo" do
      # HuggingFace returns 401 (not 404) for nonexistent repos to avoid
      # leaking info about private repos.
      assert {:error, reason} = HFClient.model_info("definitely-fake/not-a-real-repo-xyz")
      assert reason in [{:not_found, "definitely-fake/not-a-real-repo-xyz"}, {:http_error, 401}]
    end
  end

  describe "download_file/3" do
    @tag :requires_network
    test "downloads a small file to disk" do
      tmp = Path.join(System.tmp_dir!(), "ex_embed_test_#{System.unique_integer([:positive])}")
      dest = Path.join(tmp, "tokenizer.json")

      on_exit(fn -> File.rm_rf!(tmp) end)

      assert :ok = HFClient.download_file("qdrant/bge-small-en-v1.5-onnx-q", "tokenizer.json", dest)
      assert File.exists?(dest)
      assert {:ok, _} = dest |> File.read!() |> Jason.decode()
    end

    @tag :requires_network
    test "returns error for nonexistent file in valid repo" do
      tmp = Path.join(System.tmp_dir!(), "ex_embed_test_#{System.unique_integer([:positive])}")
      dest = Path.join(tmp, "nonexistent.bin")

      on_exit(fn -> File.rm_rf!(tmp) end)

      assert {:error, _} = HFClient.download_file("qdrant/bge-small-en-v1.5-onnx-q", "nonexistent_file.bin", dest)
    end

    @tag :requires_network
    test "failed download leaves no partial file at dest" do
      tmp = Path.join(System.tmp_dir!(), "ex_embed_test_#{System.unique_integer([:positive])}")
      dest = Path.join(tmp, "should_not_exist.bin")

      on_exit(fn -> File.rm_rf!(tmp) end)

      {:error, _} = HFClient.download_file("qdrant/bge-small-en-v1.5-onnx-q", "nonexistent_file.bin", dest)
      refute File.exists?(dest), "Failed download should not leave partial file"
    end

    @tag :requires_network
    test "no .tmp file remains after successful download" do
      tmp = Path.join(System.tmp_dir!(), "ex_embed_test_#{System.unique_integer([:positive])}")
      dest = Path.join(tmp, "tokenizer.json")

      on_exit(fn -> File.rm_rf!(tmp) end)

      :ok = HFClient.download_file("qdrant/bge-small-en-v1.5-onnx-q", "tokenizer.json", dest)
      refute File.exists?(dest <> ".tmp"), "Temp file should be cleaned up"
      assert File.exists?(dest)
    end
  end
end
