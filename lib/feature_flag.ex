defmodule FeatureFlag do
  @moduledoc """
  `FeatureFlag` provides a macro that allows for conditional branching at the function level via configuration values.

  In other words, you can change what a function does at runtime by setting/modifying a config value.

  ## Use Case

  The goal of this library was to provide an elegant and consistent mechanism for changing what a function does depending on a value that can easily be modified (i.e. a configuration value).

  This could very easily be done in plain Elixir via a simple `case` statement:

      def MyApp do

        def get(key) do
          case Application.get_env(MyApp, :store_type) do
            :cache ->
              get_from_cache(key)

            :database ->
              get_from_database(key)
          end
        end
      end

  There's nothing wrong with this approach, and really no need to reach for anything else.

  However, the same code can be rewritten as such using `FeatureFlag`

      def MyApp do
        use FeatureFlag

        def get(key), feature_flag do
          :cache ->
            get_from_cache(key)

          :database ->
            get_from_database(key)
        end
      end

  When called, each case will attempt to match on the current value of `Application.get_env(:feature_flag, {MyApp, :get, 1})`.

  Beyond removing a marginal amount of code, `FeatureFlag` provides a consistent interface for defining functions with config-based branching.
  """

  defmacro __using__(_) do
    quote do
      import FeatureFlag, only: [def: 3]
    end
  end

  @doc """
  A custom version of `def` that will wrap the function in the approriate conditional logic.

  Note: You must call `Use FeatureFlag` in a module before using this macro.

  ## Example

      defmodule MyApp do
        def math(x, y), feature_flag do
          :add -> x + y
          :multiply -> x * y
          :subtract x - y
        end
      end

  To have this function perform the `:multiply` procedure, you'd set the feature flag config value like so:

     config FeatureFlag, {MyApp, :math, 2}, :multiply

  Or you can use `FeatureFlag.set/2`

      FeatureFlag.set({MyApp, :math, 2}, :multiply)
  """
  defmacro def(func, {:feature_flag, _, _}, expr) do
    {function_name, _, params} = with {:when, _, [head | _]} <- func, do: head
    mfa = {__CALLER__.module, function_name, length(params)}

    do_def(mfa, func, expr)
  end

  defmacro def(_func, _flag, _expr), do: raise_compile_error("head")

  @doc """
  Returns the current feature flag value for the given function.
  """
  @spec get(mfa()) :: term()
  def get(mfa) do
    Application.get_env(__MODULE__, mfa)
  end

  @doc """
  Sets feature flag value for the given function.
  """
  @spec set(mfa(), term()) :: :ok
  def set(mfa, value) do
    Application.put_env(__MODULE__, mfa, value)
    :ok
  end

  defp do_def(mfa, func, expr) do
    {case_block, case_type} = case_block(expr)

    expected_cases =
      Enum.map(case_block, fn {_, _, [[match] | _]} ->
        "  " <> Macro.to_string(match) <> " ->\n    .."
      end)
      |> Enum.join("\n\n")

    quote do
      def unquote(func) do
        case FeatureFlag.get(unquote(Macro.escape(mfa))) do
          unquote(case_block)
        end
      rescue
        error in CaseClauseError ->
          raise FeatureFlag.MatchError.new(
                  unquote(Macro.escape(mfa)),
                  unquote(expected_cases),
                  unquote(case_type),
                  inspect(error.term)
                )
      end
    end
  end

  defp case_block(do: [{:->, _, _} | _] = case_block), do: {case_block, :case}

  defp case_block(do: do_block, else: else_block) do
    case_block =
      quote do
        true -> unquote(do_block)
        false -> unquote(else_block)
      end

    {case_block, :do_else}
  end

  defp case_block(_), do: raise_compile_error("body")

  defp raise_compile_error(part_of_function) do
    raise CompileError,
      description: """


      It looks like you were trying to use def/3 to define a feature flag'd function, but the function #{
        part_of_function
      } isn't quite right.

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
