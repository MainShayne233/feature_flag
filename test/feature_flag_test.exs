defmodule FeatureFlagTest do
  use ExUnit.Case

  describe "def/3" do
    test "should allow for a mutli-case definition" do
      defmodule MyApp.A do
        use FeatureFlag

        def math(value), feature_flag do
          :double -> 2 * value
          :half -> value / 2
          :mod_5 -> rem(value, 5)
        end
      end

      FeatureFlag.set({MyApp.A, :math, 1}, :double)
      assert MyApp.A.math(2) == 4

      FeatureFlag.set({MyApp.A, :math, 1}, :half)
      assert MyApp.A.math(4) == 2

      FeatureFlag.set({MyApp.A, :math, 1}, :mod_5)
      assert MyApp.A.math(8) == 3
    end

    test "should allow for a do/else definition" do
      defmodule MyApp.B do
        use FeatureFlag

        def maybe_reverse_string(value), feature_flag do
          String.reverse(value)
        else
          value
        end
      end

      FeatureFlag.set({MyApp.B, :maybe_reverse_string, 1}, true)
      assert MyApp.B.maybe_reverse_string("hello") == "olleh"

      FeatureFlag.set({MyApp.B, :maybe_reverse_string, 1}, false)
      assert MyApp.B.maybe_reverse_string("hello") == "hello"
    end
  end
end
