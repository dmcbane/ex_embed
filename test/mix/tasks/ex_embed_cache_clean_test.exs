defmodule Mix.Tasks.ExEmbed.CacheCleanTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  setup do
    original = Application.get_env(:ex_embed, :cache_dir)
    on_exit(fn -> Application.put_env(:ex_embed, :cache_dir, original) end)
    :ok
  end

  test "cleans all cached models" do
    tmp = Path.join(System.tmp_dir!(), "ex_embed_cacheclean_#{System.unique_integer([:positive])}")
    model_dir = Path.join(tmp, "org/repo")
    File.mkdir_p!(model_dir)
    File.write!(Path.join(model_dir, "model.onnx"), "data")

    Application.put_env(:ex_embed, :cache_dir, tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    output = capture_io(fn -> Mix.Tasks.ExEmbed.CacheClean.run([]) end)
    assert output =~ "Cache cleared"
    refute File.dir?(tmp)
  end

  test "cleans a specific model by short name" do
    tmp = Path.join(System.tmp_dir!(), "ex_embed_cacheclean_#{System.unique_integer([:positive])}")
    target_dir = Path.join(tmp, "org/target-model")
    keep_dir = Path.join(tmp, "org/keep-model")
    File.mkdir_p!(target_dir)
    File.mkdir_p!(keep_dir)
    File.write!(Path.join(target_dir, "model.onnx"), "data")
    File.write!(Path.join(keep_dir, "model.onnx"), "keep")

    Application.put_env(:ex_embed, :cache_dir, tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    output = capture_io(fn -> Mix.Tasks.ExEmbed.CacheClean.run(["target-model"]) end)
    assert output =~ "Removing"
    refute File.dir?(target_dir)
    assert File.dir?(keep_dir)
  end

  test "reports error for nonexistent model name" do
    tmp = Path.join(System.tmp_dir!(), "ex_embed_cacheclean_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    Application.put_env(:ex_embed, :cache_dir, tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    output = capture_io(:stderr, fn -> Mix.Tasks.ExEmbed.CacheClean.run(["nonexistent"]) end)
    assert output =~ "No cached model matching"
  end
end
