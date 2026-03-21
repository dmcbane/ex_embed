defmodule ExEmbed.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ex_embed,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Elixir-native text embeddings via Ortex + Tokenizers with FastEmbed-compatible model registry",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExEmbed.Application, []}
    ]
  end

  defp deps do
    [
      {:ortex, "~> 0.1"},
      {:tokenizers, "~> 0.4"},
      {:nx, "~> 0.7"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.0"},
      # dev/test
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/dmcbane/ex_embed"}
    ]
  end

  defp docs do
    [
      main: "ExEmbed",
      source_url: "https://github.com/dmcbane/ex_embed"
    ]
  end
end
