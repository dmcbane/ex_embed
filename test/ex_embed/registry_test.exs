defmodule ExEmbed.RegistryTest do
  use ExUnit.Case, async: true

  alias ExEmbed.Registry

  test "default model is registered" do
    assert {:ok, meta} = Registry.get(Registry.default())
    assert meta.dim > 0
    assert is_binary(meta.hf_repo)
    assert is_binary(meta.model_file)
  end

  test "all registered models have required fields" do
    for model <- Registry.all() do
      assert is_binary(model.name), "#{model.name}: name must be a string"
      assert is_integer(model.dim), "#{model.name}: dim must be an integer"
      assert is_binary(model.hf_repo), "#{model.name}: hf_repo must be a string"
      assert is_binary(model.model_file), "#{model.name}: model_file must be a string"
      assert is_list(model.additional_files), "#{model.name}: additional_files must be a list"
      assert is_float(model.size_gb), "#{model.name}: size_gb must be a float"
    end
  end

  test "get returns error for unknown model" do
    assert {:error, :not_found} = Registry.get("definitely/not-a-real-model")
  end

  test "list returns non-empty list of strings" do
    names = Registry.list()
    assert is_list(names)
    assert length(names) > 0
    assert Enum.all?(names, &is_binary/1)
  end
end
