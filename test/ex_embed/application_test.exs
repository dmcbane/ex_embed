defmodule ExEmbed.ApplicationTest do
  use ExUnit.Case

  test "Cache process is started by the application supervisor" do
    assert Process.whereis(ExEmbed.Cache) != nil
  end

  test "Cache process restarts after crash" do
    pid = Process.whereis(ExEmbed.Cache)
    Process.exit(pid, :kill)
    # Give the supervisor time to restart
    Process.sleep(50)
    new_pid = Process.whereis(ExEmbed.Cache)
    assert new_pid != nil
    assert new_pid != pid
  end
end
