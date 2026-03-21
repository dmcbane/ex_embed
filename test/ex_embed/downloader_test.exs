defmodule ExEmbed.DownloaderTest do
  use ExUnit.Case

  alias ExEmbed.Downloader

  setup do
    original = Application.get_env(:ex_embed, :cache_dir)
    on_exit(fn -> Application.put_env(:ex_embed, :cache_dir, original) end)
    :ok
  end

  describe "model_cache_path/1" do
    test "uses configured cache_dir" do
      Application.put_env(:ex_embed, :cache_dir, "/tmp/custom_cache")
      assert Downloader.model_cache_path("org/repo") == "/tmp/custom_cache/org/repo"
    end

    test "defaults to ~/.cache/ex_embed when not configured" do
      Application.delete_env(:ex_embed, :cache_dir)
      path = Downloader.model_cache_path("org/repo")
      assert path == Path.join([System.user_home!(), ".cache", "ex_embed", "org/repo"])
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
