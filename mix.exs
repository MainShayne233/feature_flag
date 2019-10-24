defmodule FeatureFlag.MixProject do
  use Mix.Project

  def project do
    [
      app: :feature_flag,
      version: "0.1.0",
      elixir: ">= 1.9.0",
      deps: deps(),
      description: description(),
      package: package(),
      dialyzer: dialyzer()
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

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/feature_flag.plt"}
    ]
  end

  defp deps do
    [
      {:mix_test_watch, "~> 0.9.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false}
    ]
  end
end
