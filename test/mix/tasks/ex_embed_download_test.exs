defmodule Mix.Tasks.ExEmbed.DownloadTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "prints usage when no arguments given" do
    output = capture_io(:stderr, fn -> Mix.Tasks.ExEmbed.Download.run([]) end)
    assert output =~ "Usage"
  end
end
