defmodule TigerBeetlex.MixProject do
  use Mix.Project

  def project do
    [
      app: :tigerbeetlex,
      version: "0.1.0",
      elixir: "~> 1.14",
      install_zig: "0.11.0",
      zig_build_mode: zig_build_mode(Mix.env()),
      compilers: [:build_dot_zig] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_add_apps: [:zig_parser]],
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

  defp zig_build_mode(:prod), do: :release_safe
  defp zig_build_mode(_env), do: :debug

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:typed_struct, "~> 0.3.0"},
      {:nimble_options, "~> 1.0"},
      {:zig_parser, "~> 0.2.0", runtime: false},
      {:build_dot_zig, "~> 0.5.0", runtime: false},
      {:uniq, "~> 0.6", only: :test},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end
end
