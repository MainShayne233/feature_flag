defmodule FeatureFlag do
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
