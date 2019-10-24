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

  defp do_def({module_name, func_name, arity} = name, func, expr) do
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
                  unquote(inspect(module_name)),
                  unquote(func_name),
                  unquote(arity),
                  unquote(expected_cases),
                  unquote(case_type),
                  inspect(error.term)
                )
      end
    end
  end

  def get(name) do
    Application.get_env(__MODULE__, name)
  end

  def set(name, value) do
    Application.put_env(__MODULE__, name, value)
  end

  defp case_block(do: [{:->, _, _} | _] = case_block), do: {case_block, :case}

  defp case_block(do: do_block, else: else_block) do
    {quote do
       true -> unquote(do_block)
       false -> unquote(else_block)
     end, :do_else}
  end
end
