defmodule Mix.Tasks.ExEmbed.ListTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "prints a table of registered models" do
    output = capture_io(fn -> Mix.Tasks.ExEmbed.List.run([]) end)

    # Header is present
    assert output =~ "Registered ExEmbed models"
    assert output =~ "Name"
    assert output =~ "Dim"

    # Known models appear in the output
    assert output =~ "BAAI/bge-small-en-v1.5"
    assert output =~ "384"
  end

  test "includes all registered models" do
    output = capture_io(fn -> Mix.Tasks.ExEmbed.List.run([]) end)

    for name <- ExEmbed.Registry.list() do
      assert output =~ name, "Expected #{name} in list output"
    end
  end
end
