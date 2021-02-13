defmodule NervesGardenTest do
  use ExUnit.Case
  doctest NervesGarden

  test "greets the world" do
    assert NervesGarden.hello() == :world
  end
end
