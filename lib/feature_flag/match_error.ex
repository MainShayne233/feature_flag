defmodule FeatureFlag.MatchError do
  alias FeatureFlag.Definition

  @type t :: Exception.t()

  defexception [:message]

  @doc """
  Returns a new FeatureFlag.MatchError.
  """
  @spec new(Definition.t(), Exception.t()) :: t()
  def new(definition, error) do
    %__MODULE__{
      message: """


      I couldn't match on the feature flag value for #{Definition.to_mfa_string(definition)}

      #{expecting_message(definition)}
      but instead got: #{inspect(error.term)}
      """
    }
  end

  @spec expecting_message(Definition.t()) :: String.t()
  def expecting_message(%Definition{case_type: :match} = definition),
    do: """
    I was expecting a value that'd match in the following cases:

    #{Definition.to_expected_cases_string(definition)}
    """

  def expecting_message(%Definition{case_type: :do_else}),
    do: """
    I was expecting either true or false
    """
end
