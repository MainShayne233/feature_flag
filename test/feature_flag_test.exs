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
          _ -> 5
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

    test "should raise a helpful error when feature flag's value isn't matched on" do
      defmodule MyApp.C do
        use FeatureFlag

        def math(value), feature_flag do
          :double -> 2 * value
          :half -> value / 2
          :mod_5 -> rem(value, 5)
        end
      end

      FeatureFlag.set({MyApp.C, :math, 1}, :quadruple)

      error = assert_raise(FeatureFlag.MatchError, fn ->
        MyApp.C.math(2)
              end)

      assert error.message == """


      I couldn't match on the feature flag value for FeatureFlagTest.MyApp.C.math/1

      I was expecting a value that'd match in the following cases:

        :double ->
          ..

        :half ->
          ..

        :mod_5 ->
          ..

      but instead got: :quadruple
      """
    end

    test "should raise a specialized error specific to the do/else case when it is used" do
      defmodule MyApp.D do
        use FeatureFlag

        def maybe_reverse_string(value), feature_flag do
          String.reverse(value)
        else
          value
        end
      end

      FeatureFlag.set({MyApp.D, :maybe_reverse_string, 1}, nil)

      error = assert_raise(FeatureFlag.MatchError, fn ->
        MyApp.D.maybe_reverse_string("hello")
      end)

      assert error.message == """


      I couldn't match on the feature flag value for FeatureFlagTest.MyApp.D.maybe_reverse_string/1

      I was expecting either true or false

      but instead got: nil
      """
    end
  end
end
