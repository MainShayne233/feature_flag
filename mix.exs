defmodule FeatureFlag.MixProject do
  use Mix.Project

  def project do
    [
      app: :feature_flag,
      version: "0.1.5",
      elixir: ">= 1.9.0",
      deps: deps(),
      description: description(),
      package: package(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp description, do: "Change what Elixir functions do via configuration values"

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
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.12.0", only: [:dev, :test], runtime: false}
    ]
  end
end
