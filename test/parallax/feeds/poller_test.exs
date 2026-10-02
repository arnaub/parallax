defmodule Parallax.Feeds.PollerTest do
  use ExUnit.Case, async: true

  alias Parallax.Feeds.Poller

  test "starts without polling synchronously" do
    assert {:ok, pid} = Poller.start_link([])
    assert Process.alive?(pid)
    GenServer.stop(pid)
  end
end
