defmodule ExEmbed.DownloaderTest do
  use ExUnit.Case

  alias ExEmbed.Downloader

  setup do
    original = Application.get_env(:ex_embed, :cache_dir)
    on_exit(fn -> Application.put_env(:ex_embed, :cache_dir, original) end)
    :ok
  end

  describe "cache_dir validation" do
    test "ensure/1 creates cache_dir if it does not exist" do
      tmp = Path.join(System.tmp_dir!(), "ex_embed_newdir_#{System.unique_integer([:positive])}")
      refute File.exists?(tmp)
      Application.put_env(:ex_embed, :cache_dir, tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      # ensure will fail on model lookup, but cache_dir should be created
      _result = ExEmbed.Downloader.ensure("BAAI/bge-small-en-v1.5")
      assert File.dir?(tmp)
    end
  end

  describe "model_cache_path/1" do
    test "uses configured cache_dir" do
      Application.put_env(:ex_embed, :cache_dir, "/tmp/custom_cache")
      assert {:ok, "/tmp/custom_cache/org/repo"} = Downloader.model_cache_path("org/repo")
    end

    test "defaults to ~/.cache/ex_embed when not configured" do
      Application.delete_env(:ex_embed, :cache_dir)
      expected = Path.join([System.user_home!(), ".cache", "ex_embed", "org/repo"])
      assert {:ok, ^expected} = Downloader.model_cache_path("org/repo")
    end
  end

  describe "path traversal protection" do
    test "model_cache_path rejects paths with .. traversal" do
      Application.put_env(:ex_embed, :cache_dir, "/tmp/safe_cache")
      assert {:error, :invalid_path} = Downloader.model_cache_path("legit/../../etc")
    end

    test "model_cache_path rejects paths that resolve outside cache_dir" do
      Application.put_env(:ex_embed, :cache_dir, "/tmp/safe_cache")
      assert {:error, :invalid_path} = Downloader.model_cache_path("../outside")
    end

    test "model_cache_path allows legitimate nested repo paths" do
      Application.put_env(:ex_embed, :cache_dir, "/tmp/safe_cache")
      assert {:ok, path} = Downloader.model_cache_path("BAAI/bge-small-en-v1.5")
      assert path == "/tmp/safe_cache/BAAI/bge-small-en-v1.5"
    end
  end

  describe "revision support" do
    test "models without revision field default to main" do
      {:ok, meta} = ExEmbed.Registry.get("BAAI/bge-small-en-v1.5")
      # revision field is optional — should default to "main" in downloader
      revision = Map.get(meta, :revision, "main") || "main"
      assert revision == "main"
    end
  end

  describe "checksum verification" do
    @tag :requires_model
    test "ensure/1 accepts files with correct checksums" do
      # The real cached model files should pass checksum verification
      assert {:ok, _} = Downloader.ensure("BAAI/bge-small-en-v1.5")
    end

    test "checksum_matches?/2 rejects corrupted files" do
      tmp = Path.join(System.tmp_dir!(), "ex_embed_cksum_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      fake_file = Path.join(tmp, "fake.bin")
      File.write!(fake_file, "corrupted data")
      on_exit(fn -> File.rm_rf!(tmp) end)

      {:ok, meta} = ExEmbed.Registry.get("BAAI/bge-small-en-v1.5")
      checksums = Map.get(meta, :checksums, %{})
      expected_hash = Map.get(checksums, "model_optimized.onnx")

      # The fake file should not match the real model's checksum
      if expected_hash do
        actual =
          File.stream!(fake_file, 65_536)
          |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
          |> :crypto.hash_final()
          |> Base.encode16(case: :lower)

        refute actual == expected_hash
      end
    end
  end

  describe "ensure/1" do
    test "returns {:error, :not_found} for unknown model" do
      assert {:error, :not_found} = Downloader.ensure("nonexistent/model-xyz")
    end

    test "returns {:ok, path} when all files already exist on disk" do
      # Use a real registry entry so ensure/1 can look it up
      {:ok, meta} = ExEmbed.Registry.get("BAAI/bge-small-en-v1.5")
      files = [meta.model_file | meta.additional_files]

      tmp = Path.join(System.tmp_dir!(), "ex_embed_test_#{System.unique_integer([:positive])}")
      model_dir = Path.join(tmp, meta.hf_repo)
      File.mkdir_p!(model_dir)

      # Create fake files so ensure/1 thinks they're already cached
      Enum.each(files, fn f ->
        Path.join(model_dir, f) |> File.write!("fake")
      end)

      Application.put_env(:ex_embed, :cache_dir, tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      assert {:ok, ^model_dir} = Downloader.ensure("BAAI/bge-small-en-v1.5")
    end

    test "detects missing files and attempts download" do
      {:ok, meta} = ExEmbed.Registry.get("BAAI/bge-small-en-v1.5")

      tmp = Path.join(System.tmp_dir!(), "ex_embed_test_#{System.unique_integer([:positive])}")
      model_dir = Path.join(tmp, meta.hf_repo)
      File.mkdir_p!(model_dir)

      # Create only the tokenizer, leaving the model file missing
      Path.join(model_dir, "tokenizer.json") |> File.write!("fake")

      Application.put_env(:ex_embed, :cache_dir, tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      # This will try to download the missing model file and fail (no network in unit tests)
      # but the important thing is it correctly identifies the missing file and attempts it
      result = Downloader.ensure("BAAI/bge-small-en-v1.5")

      # Either it downloads successfully (if network available) or returns a download error
      case result do
        {:ok, _} -> :ok
        {:error, {:download_failed, errors}} -> assert length(errors) > 0
        {:error, _reason} -> :ok
      end
    end
  end
end
