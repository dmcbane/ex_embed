defmodule Mix.Tasks.ExEmbed.CacheListTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  setup do
    original = Application.get_env(:ex_embed, :cache_dir)
    on_exit(fn -> Application.put_env(:ex_embed, :cache_dir, original) end)
    :ok
  end

  test "lists cached models with sizes" do
    tmp = Path.join(System.tmp_dir!(), "ex_embed_cachelist_#{System.unique_integer([:positive])}")
    model_dir = Path.join(tmp, "org/repo")
    File.mkdir_p!(model_dir)
    File.write!(Path.join(model_dir, "model.onnx"), String.duplicate("x", 1024))
    File.write!(Path.join(model_dir, "tokenizer.json"), "{}")

    Application.put_env(:ex_embed, :cache_dir, tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    output = capture_io(fn -> Mix.Tasks.ExEmbed.CacheList.run([]) end)

    assert output =~ "org/repo"
    assert output =~ "KB" or output =~ "B"
    assert output =~ "Total"
  end

  test "reports when cache is empty" do
    tmp = Path.join(System.tmp_dir!(), "ex_embed_cachelist_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    Application.put_env(:ex_embed, :cache_dir, tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    output = capture_io(fn -> Mix.Tasks.ExEmbed.CacheList.run([]) end)
    assert output =~ "No cached models"
  end

  test "handles nonexistent cache directory" do
    Application.put_env(:ex_embed, :cache_dir, "/tmp/definitely_not_a_dir_#{System.unique_integer()}")

    output = capture_io(fn -> Mix.Tasks.ExEmbed.CacheList.run([]) end)
    assert output =~ "does not exist"
  end
end
