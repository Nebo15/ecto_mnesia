defmodule EctoMnesia.Mixfile do
  use Mix.Project

  @version "0.9.0"

  def project do
    [
      app: :ecto_mnesia,
      description: "Ecto adapter for Mnesia erlang term storage.",
      package: package(),
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [] ++ Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      docs: [source_ref: "v#\{@version\}", main: "readme", extras: ["README.md"]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :mnesia, :confex, :ecto]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:confex, "~> 3.3"},
      {:decimal, "~> 1.5"},
      {:ecto, "~> 2.2.0"},
      {:ex_doc, "~> 0.18", only: [:dev, :test]},
      {:excoveralls, "~> 0.8", only: [:dev, :test]}
    ]
  end

  # Settings for publishing in Hex package manager:
  defp package do
    [
      contributors: ["Maxim Sokhatsky (5ht)", "Nebo #15"],
      maintainers: ["Nebo #15"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/Nebo15/ecto_mnesia"},
      files: ~w(lib LICENSE.md mix.exs README.md)
    ]
  end
end
