defmodule FeatureFlag do
  defmacro __using__(_) do
    quote do
      import FeatureFlag, only: [def: 3]
    end
  end

  defmacro def({func_name, _, params} = call, {:feature_flag, _, _}, expr) do
    module_name = __CALLER__.module
    arity = length(params)
    name = {module_name, func_name, arity}
    {case_block, case_type} = case_block(expr)

    expected_cases =
      Enum.map(case_block, fn {_, _, [[match] | _]} ->
        "  " <> Macro.to_string(match) <> " ->\n    .."
      end)
      |> Enum.join("\n\n")

    quote do
      def unquote(call) do
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
