defmodule TigerBeetlex.MixProject do
  use Mix.Project

  def project do
    [
      app: :tigerbeetlex,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {TigerBeetlex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:build_dot_zig, "~> 0.1.0", runtime: false}
    ]
  end
end
