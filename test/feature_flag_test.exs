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

      error =
        assert_raise(FeatureFlag.MatchError, fn ->
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

      error =
        assert_raise(FeatureFlag.MatchError, fn ->
          MyApp.D.maybe_reverse_string("hello")
        end)

      assert error.message == """


             I couldn't match on the feature flag value for FeatureFlagTest.MyApp.D.maybe_reverse_string/1

             I was expecting either true or false

             but instead got: nil
             """
    end

    test "should allow for guard clauses" do
      defmodule MyApp.E do
        use FeatureFlag

        def math(value) when is_number(value), feature_flag do
          :double -> {:ok, 2 * value}
          :half -> {:ok, value / 2}
          :mod_5 -> {:ok, rem(value, 5)}
        end

        def math(_), do: :error
      end

      FeatureFlag.set({MyApp.E, :math, 1}, :double)
      assert MyApp.E.math(2) == {:ok, 4}
      assert MyApp.E.math("2") == :error
    end

    test "should raise a helpful compile error if you fail to define def/3 correctly" do
      error =
        assert_raise(CompileError, fn ->
          defmodule MyApp.F do
            use FeatureFlag

            def math(value) when is_number(value), feature do
              :double -> {:ok, 2 * value}
              :half -> {:ok, value / 2}
              :mod_5 -> {:ok, rem(value, 5)}
            end

            def math(_), do: :error
          end
        end)

      assert error.description == """


             It looks like you were trying to use def/3 to define a feature flag'd function, but it's not quite right.

             The function definition should look something like:

             def function_name(arg1, arg2), feature_flag do
               :a -> ...
               :b -> ...
             end

             or

             def function_name(arg1, arg2), feature_flag do
               ...
             else
               ...
             end
             """
    end
  end
end
