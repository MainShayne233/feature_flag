defmodule FeatureFlag.MixProject do
  use Mix.Project

  def project do
    [
      app: :feature_flag,
      version: "0.0.4",
      elixir: ">= 1.9.0",
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  defp description,
    do:
      "A succinct and consistent interface for defining control-flow of functions via configuration."

  defp package do
    [
      name: "feature_flag",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/MainShayne233/feature_flag"}
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
