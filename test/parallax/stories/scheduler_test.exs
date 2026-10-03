defmodule Parallax.Stories.SchedulerTest do
  use ExUnit.Case, async: true

  alias Parallax.Stories.Scheduler

  test "starts without clustering synchronously" do
    assert {:ok, pid} = Scheduler.start_link([])
    assert Process.alive?(pid)
    GenServer.stop(pid)
  end
end
