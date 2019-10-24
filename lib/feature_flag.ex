defmodule FeatureFlag do
  @moduledoc """
  `FeatureFlag` provides a macro that allows for conditional branching at the function level via configuration values.

  In other words, you can change what a function does by setting/modifying a config value.

  Here's a simple example:

      defmodule MyApp
        use FeatureFlag

        def get(key), feature_flag do
          :cache ->
            get_from_cache(key)

          :database ->
            get_from_database(key)
        end
      end

  The function `MyApp.get/1` will perform different procedures depending on a config value you can set via:

  `config FeatureFlag, {MyApp, :get, 1}, :cache`

  or, you can set/change this value at runtime via:

  `FeatureFlag.set({MyApp, :get, 1}, :database)`


  If your function is only going to do one of two things based on a boolean feature flag, you can simplify
  your function like so:

      def get(key), feature_flag do
        get_from_cache(key)
      else
        get_from_database(key)
      end

  The first block will get called if `Application.get_env(FeatureFlag, {MyApp, :get, 1}) == true`, and the else block will get called if it's `false`.
  """

  defmacro __using__(_) do
    quote do
      import FeatureFlag, only: [def: 3]
    end
  end

  defmacro def(func, {:feature_flag, _, _}, expr) do
    {function_name, _, params} = with {:when, _, [head | _]} <- func, do: head
    name = {__CALLER__.module, function_name, length(params)}

    do_def(name, func, expr)
  end

  defmacro def(_func, _flag, _expr), do: raise_compile_error("head")

  def get(name) do
    Application.get_env(__MODULE__, name)
  end

  def set(name, value) do
    Application.put_env(__MODULE__, name, value)
  end

  defp do_def(name, func, expr) do
    {case_block, case_type} = case_block(expr)

    expected_cases =
      Enum.map(case_block, fn {_, _, [[match] | _]} ->
        "  " <> Macro.to_string(match) <> " ->\n    .."
      end)
      |> Enum.join("\n\n")

    quote do
      def unquote(func) do
        case FeatureFlag.get(unquote(Macro.escape(name))) do
          unquote(case_block)
        end
      rescue
        error in CaseClauseError ->
          raise FeatureFlag.MatchError.new(
                  unquote(Macro.escape(name)),
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
