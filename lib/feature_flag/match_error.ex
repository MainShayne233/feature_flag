defmodule FeatureFlag.MatchError do
  @type t :: Exception.t()

  defexception [:message]

  @doc """
  Returns a new FeatureFlag.MatchError.
  """
  @spec new(mfa(), String.t(), :case | :do_else, term()) :: t()
  def new({module_name, func_name, arity}, expected_cases, case_type, actual) do
    %__MODULE__{
      message: """


      I couldn't match on the feature flag value for #{inspect(module_name)}.#{func_name}/#{arity}

      #{expecting_message(expected_cases, case_type)}
      but instead got: #{actual}
      """
    }
  end

  @spec expecting_message(String.t(), :case | :do_else) :: String.t()
  def expecting_message(expected_cases, :case),
    do: """
    I was expecting a value that'd match in the following cases:

    #{expected_cases}
    """

  def expecting_message(_expected_cases, :do_else),
    do: """
    I was expecting either true or false
    """
end
