defmodule TigerBeetlex.MixProject do
  use Mix.Project

  def project do
    [
      app: :tigerbeetlex,
      version: "0.16.38",
      elixir: "~> 1.14",
      install_zig: "0.13.0",
      zig_build_mode: zig_build_mode(Mix.env()),
      compilers: [:build_dot_zig] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      source_url: "https://github.com/rbino/tigerbeetlex",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp zig_build_mode(:prod), do: :release_safe
  defp zig_build_mode(_env), do: :debug

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:typed_struct, "~> 0.3.0"},
      {:nimble_options, "~> 1.0"},
      {:build_dot_zig, "~> 0.6.1", runtime: false},
      {:uniq, "~> 0.6", only: :test},
      {:styler, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.32", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Elixir client for TigerBeetle, the financial transactions database."
  end

  defp package do
    [
      files: ~w(lib src tools .formatter.exs mix.exs README* LICENSE*
                CHANGELOG* build.zig build.zig.zon),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/rbino/tigerbeetlex"}
    ]
  end
end
