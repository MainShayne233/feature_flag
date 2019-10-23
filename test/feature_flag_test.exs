defmodule FeatureFlagTest do
  use ExUnit.Case
  doctest FeatureFlag

  test "greets the world" do
    assert FeatureFlag.hello() == :world
  end
end
