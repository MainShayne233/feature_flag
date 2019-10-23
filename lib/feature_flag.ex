defmodule FeatureFlag do
  defmacro __using__(_) do
    quote do
      import FeatureFlag, only: [def: 3]
    end
  end

  defmacro def({func_name, _, params} = call, {:feature_flag, _, _}, expr) do
    name = {__CALLER__.module, func_name, length(params)}

    quote do
      def unquote(call) do
        case FeatureFlag.get(unquote(Macro.escape(name))) do
          unquote(case_block(expr))
        end
      end
    end
  end

  defp case_block(do: [{:->, _, _} | _] = case_block), do: case_block

  defp case_block(do: do_block, else: else_block) do
    quote do
      true -> unquote(do_block)
      false -> unquote(else_block)
    end
  end

  def get(name) do
    Application.get_env(__MODULE__, name)
  end

  def set(name, value) do
    Application.put_env(__MODULE__, name, value)
  end
end
