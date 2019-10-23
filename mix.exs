defmodule FeatureFlag.MixProject do
  use Mix.Project

  def project do
    [
      app: :feature_flag,
      version: "0.0.1",
      elixir: ">= 1.9.0",
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:mix_test_watch, "~> 0.9.0"}
    ]
  end
end
