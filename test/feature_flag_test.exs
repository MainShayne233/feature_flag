defmodule FeatureFlagTest do
  use ExUnit.Case

  describe "def/3" do
    test "should allow for a mutli-case definition" do
      init_flags(%{
        {FeatureFlagTest.MyApp.A, :math, 1} => :double
      })

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
      init_flags(%{
        {FeatureFlagTest.MyApp.B, :maybe_reverse_string, 1} => true
      })

      defmodule MyApp.B do
        use FeatureFlag

        def maybe_reverse_string(value), feature_flag do
          String.reverse(value)
        else
          value
        end
      end

      assert MyApp.B.maybe_reverse_string("hello") == "olleh"

      FeatureFlag.set({MyApp.B, :maybe_reverse_string, 1}, false)
      assert MyApp.B.maybe_reverse_string("hello") == "hello"
    end

    test "should raise a helpful error when feature flag's value isn't matched on" do
      init_flags(%{
        {FeatureFlagTest.MyApp.C, :math, 1} => :quadruple
      })

      defmodule MyApp.C do
        use FeatureFlag

        def math(value), feature_flag do
          :double -> 2 * value
          :half -> value / 2
          :mod_5 -> rem(value, 5)
        end
      end

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
      init_flags(%{
        {FeatureFlagTest.MyApp.D, :maybe_reverse_string, 1} => nil
      })

      defmodule MyApp.D do
        use FeatureFlag

        def maybe_reverse_string(value), feature_flag do
          String.reverse(value)
        else
          value
        end
      end

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
      init_flags(%{
        {FeatureFlagTest.MyApp.E, :math, 1} => :double
      })

      defmodule MyApp.E do
        use FeatureFlag

        def math(value) when is_number(value), feature_flag do
          :double -> {:ok, 2 * value}
          :half -> {:ok, value / 2}
          :mod_5 -> {:ok, rem(value, 5)}
        end

        def math(_), do: :error
      end

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
          end
        end)

      assert error.description == """


             It looks like you were trying to use def/3 to define a feature flag'd function, but the function head isn't quite right.

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

    test "should raise a helpful compile error if the body of the function isn't valid" do
      init_flags(%{
        {FeatureFlagTest.MyApp.F, :math, 1} => :divide
      })

      error =
        assert_raise(CompileError, fn ->
          defmodule MyApp.F do
            use FeatureFlag

            def math(value) when is_number(value), feature_flag do
              {:ok, value}
            end
          end
        end)

      assert error.description == """


             It looks like you were trying to use def/3 to define a feature flag'd function, but the function body isn't quite right.

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

    test "should raise a helpful compile error if a feature flag's value isn't previousily set" do
      error =
        assert_raise(CompileError, fn ->
          defmodule MyApp.G do
            use FeatureFlag

            def math(value), feature_flag do
              :multuply -> value * 2
              :divide -> value / 2
            end
          end
        end)

      assert error.description == """


             Hm, it seems there is no feature flag value set for FeatureFlagTest.MyApp.G.math/1

             This value must be set to ensure it has at least been accounted for, even if it's set to `nil`.

             You can set the feature flag configuration for this particular function by adding the following to your config:

                 config FeatureFlag, :flags, %{{FeatureFlagTest.MyApp.G, :math, 1} => :flag_value}


             The value can also be set outside of a config file via `FeatureFlag.set/2`, like:

                 FeatureFlag.set({FeatureFlagTest.MyApp.G, :math, 1}, :flag_value)
             """
    end
  end

  describe "defp" do
    test "should allow for defp definitions" do
      init_flags(%{
        {FeatureFlagTest.MyApp.H, :do_math, 1} => :double
      })

      defmodule MyApp.H do
        use FeatureFlag

        def math(value), do: do_math(value)

        defp do_math(value), feature_flag do
          :double -> 2 * value
          :half -> value / 2
          :mod_5 -> rem(value, 5)
          _ -> 5
        end
      end

      FeatureFlag.set({MyApp.H, :do_math, 1}, :double)
      assert MyApp.H.math(2) == 4
    end

    test "should raise helpful compile error if a defp/3 is definied incorrectly" do
      error =
        assert_raise(CompileError, fn ->
          defmodule MyApp.I do
            use FeatureFlag

            defp math(value), feature do
              :double -> {:ok, 2 * value}
              :half -> {:ok, value / 2}
              :mod_5 -> {:ok, rem(value, 5)}
            end
          end
        end)

      assert error.description == """


             It looks like you were trying to use defp/3 to define a feature flag'd function, but the function head isn't quite right.

             The function definition should look something like:

             defp function_name(arg1, arg2), feature_flag do
               :a -> ...
               :b -> ...
             end

             or

             defp function_name(arg1, arg2), feature_flag do
               ...
             else
               ...
             end
             """
    end
  end

  defp init_flags(flags) do
    Application.put_env(FeatureFlag, :flags, flags)
  end
end
