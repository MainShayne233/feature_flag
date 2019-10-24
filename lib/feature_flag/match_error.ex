defmodule FeatureFlag.MatchError do
  defexception [:message]

  def new({module_name, func_name, arity}, expected_cases, case_type, actual) do
    %__MODULE__{
      message: """


      I couldn't match on the feature flag value for #{inspect(module_name)}.#{func_name}/#{arity}

      #{expecting_message(expected_cases, case_type)}
      but instead got: #{actual}
      """
    }
  end

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
