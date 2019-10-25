defmodule FeatureFlag do
  defmodule Definition do
    @moduledoc """
    An internal struct representing a feature flag definition.
    """

    @type def_type :: :def | :defp
    @type case_type :: :match | :do_else

    @type t :: %__MODULE__{
            def_type: def_type(),
            mfa: mfa(),
            head: Macro.t(),
            case_type: case_type(),
            case_expr: Macro.t()
          }

    @enforce_keys [:def_type, :mfa, :head, :case_type, :case_expr]

    defstruct @enforce_keys

    def to_mfa_string(%Definition{mfa: {module, func, arity}}) do
      "#{inspect(module)}.#{func}/#{arity}"
    end

    def to_expected_cases_string(%Definition{case_expr: case_expr}) do
      Enum.map(case_expr, fn {_, _, [[match] | _]} ->
        "  " <> Macro.to_string(match) <> " ->\n    .."
      end)
      |> Enum.join("\n\n")
    end
  end

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
      import FeatureFlag, only: [def: 3, defp: 3]
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

     config :feature_flag, :flags, %{{MyApp, :math, 2} => :multiply}

  Or you can use `FeatureFlag.set/2`

      FeatureFlag.set({MyApp, :math, 2}, :multiply)
  """
  @spec def(Macro.t(), Macro.t(), Macro.t()) ::
          Macro.t() | no_return()
  defmacro def(head, {:feature_flag, _, _}, expr) do
    parse_and_define(:def, __CALLER__.module, head, expr)
  end

  defmacro def(_func, _flag, _expr), do: raise_compile_error(:def, "head")

  @doc """
  The same as FeatureFlag.def/3, but for private functions.
  """
  @spec defp(Macro.t(), Macro.t(), Macro.t()) ::
          Macro.t() | no_return()
  defmacro defp(head, {:feature_flag, _, _}, expr) do
    parse_and_define(:defp, __CALLER__.module, head, expr)
  end

  defmacro defp(_func, _flag, _expr), do: raise_compile_error(:defp, "head")

  defp parse_and_define(def_type, module, head, expr) do
    {function_name, _, params} = with {:when, _, [inner_head | _]} <- head, do: inner_head
    mfa = {module, function_name, length(params)}
    {case_expr, case_type} = case_expr(def_type, expr)

    definition = %Definition{
      def_type: def_type,
      mfa: mfa,
      head: head,
      case_type: case_type,
      case_expr: case_expr
    }

    :ok = ensure_configuration_is_set!(definition)

    define(definition)
  end

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
    Application.put_env(:feature_flag, :flags, updated_flags)
    :ok
  end

  @spec get_flags! :: map() | no_return()
  defp get_flags!, do: Application.fetch_env!(:feature_flag, :flags)

  @spec define(Definition.t()) :: Macro.t()
  defp define(
         %Definition{def_type: def_type, mfa: mfa, head: head, case_expr: case_expr} = definition
       ) do
    do_expr =
      quote do
        case FeatureFlag.get(unquote(Macro.escape(mfa))) do
          unquote(case_expr)
        end
      end

    rescue_expr =
      quote do
        error in CaseClauseError ->
          raise FeatureFlag.MatchError.new(unquote(Macro.escape(definition)), error)
      end

    case def_type do
      :def ->
        quote(do: def(unquote(head), do: unquote(do_expr), rescue: unquote(rescue_expr)))

      :defp ->
        quote(do: defp(unquote(head), do: unquote(do_expr), rescue: unquote(rescue_expr)))
    end
  end

  @spec case_expr(Definition.def_type(), Keyword.t()) ::
          {Macro.t(), :case | :do_else} | no_return()
  defp case_expr(_def_type, do: [{:->, _, _} | _] = case_expr), do: {case_expr, :match}

  defp case_expr(_def_type, do: do_block, else: else_block) do
    case_expr =
      quote do
        true -> unquote(do_block)
        false -> unquote(else_block)
      end

    {case_expr, :do_else}
  end

  defp case_expr(def_type, _), do: raise_compile_error(def_type, "body")

  @spec ensure_configuration_is_set!(Definition.t()) :: :ok | no_return()
  defp ensure_configuration_is_set!(%Definition{mfa: mfa} = definition) do
    case Application.fetch_env(:feature_flag, :flags) do
      {:ok, %{^mfa => _}} ->
        :ok

      _ ->
        raise CompileError,
          description: """


          Hm, it seems there is no feature flag value set for #{
            Definition.to_mfa_string(definition)
          }

          This value must be set to ensure it has at least been accounted for, even if it's set to `nil`.

          You can set the feature flag configuration for this particular function by adding the following to your config:

              config :feature_flag, :flags, %{#{inspect(mfa)} => :flag_value}


          The value can also be set outside of a config file via `FeatureFlag.set/2`, like:

              FeatureFlag.set(#{inspect(mfa)}, :flag_value)
          """
    end
  end

  @spec raise_compile_error(Definition.def_type(), String.t()) :: no_return()
  defp raise_compile_error(def_type, part_of_function) do
    raise CompileError,
      description: """


      It looks like you were trying to use #{def_type}/3 to define a feature flag'd function, but the function #{
        part_of_function
      } isn't quite right.

      The function definition should look something like:

      #{def_type} function_name(arg1, arg2), feature_flag do
        :a -> ...
        :b -> ...
      end

      or

      #{def_type} function_name(arg1, arg2), feature_flag do
        ...
      else
        ...
      end
      """
  end
end
