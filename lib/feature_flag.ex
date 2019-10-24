defmodule FeatureFlag do
  @moduledoc """
  `FeatureFlag` provides a macro that allows for conditional branching at the function level via configuration values.

  In other words, you can change what a function does at runtime by setting/modifying a config value.

  ## Use Case

  The goal of this library was to provide an elegant and consistent mechanism for changing what a function does depending on a value that can easily be modified (i.e. a configuration value).

  This could very easily be done in plain Elixir via a simple `case` statement:

      defmodule MyApp do
        def math(x, y) do
          case Application.fetch_env!(:my_app, :math) do
            :add -> x + y
            :multiply -> x * y
            :subtract x - y
          end
        end
      end

  There's nothing wrong with this approach, and really no need to reach for anything else.

  However, the same code can be rewritten as such using `FeatureFlag`

    defmodule MyApp do
      def math(x, y), feature_flag do
        :add -> x + y
        :multiply -> x * y
        :subtract x - y
      end
    end

  When called, each case will attempt to match on the current value of `Application.fetch_env!(:feature_flag, {MyApp, :math, 2})`.

  Beyond removing a marginal amount of code, `FeatureFlag` provides a consistent interface for defining functions with config-based branching.
  """

  @doc """
  The function that gets called when `use FeatureFlag` gets called.

  It simply imports the `def/3` macro.
  """
  @spec __using__([]) :: Macro.t()
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

     config FeatureFlag, :flags, %{{MyApp, :math, 2} => :multiply}

  Or you can use `FeatureFlag.set/2`

      FeatureFlag.set({MyApp, :math, 2}, :multiply)
  """
  @spec def(func :: Macro.t(), feature_flag :: Macro.t(), expression :: Macro.t()) ::
          Macro.t() | no_return()
  defmacro def(func, {:feature_flag, _, _}, expr) do
    {function_name, _, params} = with {:when, _, [head | _]} <- func, do: head
    mfa = {__CALLER__.module, function_name, length(params)}
    :ok = ensure_configuration_is_set!(mfa)

    do_def(mfa, func, expr)
  end

  defmacro def(_func, _flag, _expr), do: raise_compile_error("head")

  @doc """
  Returns the current feature flag value for the given function.
  """
  @spec get(mfa()) :: term()
  def get(mfa) do
    Map.fetch!(get_flags!(), mfa)
  end

  @doc """
  Sets feature flag value for the given function.
  """
  @spec set(mfa(), term()) :: :ok
  def set(mfa, value) do
    updated_flags = %{get_flags!() | mfa => value}
    Application.put_env(__MODULE__, :flags, updated_flags)
    :ok
  end

  @spec get_flags! :: map() | no_return()
  defp get_flags!, do: Application.fetch_env!(__MODULE__, :flags)

  @spec do_def(mfa(), Macro.t(), Macro.t()) :: Macro.t()
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

  @spec case_block(Keyword.t()) :: {Macro.t(), :case | :do_else} | no_return()
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

  @spec ensure_configuration_is_set!(mfa()) :: :ok | no_return()
  defp ensure_configuration_is_set!({module, func, arity} = mfa) do
    case Application.fetch_env(FeatureFlag, :flags) do
      {:ok, %{^mfa => _}} ->
        :ok

      _ ->
        raise CompileError,
          description: """


          Hm, it seems their is no feature flag value set for #{inspect(module)}.#{func}/#{arity}

          This value must be set to ensure it has at least been encounted for, even if it's set to `nil`.

          You can set the feature flag configuration for this particular function by adding the following to your config:

              config FeatureFlag, :flags, %{#{inspect(mfa)} => :flag_value}


          The value can also be set via outside of a config file via `FeatureFlag.set/2`, like:

              FeatureFlag.set(#{inspect(mfa)}, :flag_value)
          """
    end
  end

  @spec raise_compile_error(String.t()) :: no_return()
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
