defmodule LightswitchTest do
  use ExUnit.Case
  doctest Lightswitch

  test "greets the world" do
    assert Lightswitch.hello() == :world
  end
end
