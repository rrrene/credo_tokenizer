defmodule CredoTokenizer.MixProject do
  use Mix.Project

  def project do
    [
      app: :credo_tokenizer,
      version: "0.2.5",
      elixir: "~> 1.15",
      description: "A fork of Elixir's tokenizer for Credo",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "src",
        "LICENSE",
        "mix.exs",
        "README.md"
      ],
      maintainers: ["René Föhring"],
      licenses: ["Apache-2.0"],
      links: %{}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end
end
