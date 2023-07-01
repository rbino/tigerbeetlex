defmodule TigerBeetlex.MixProject do
  use Mix.Project

  def project do
    [
      app: :tigerbeetlex,
      version: "0.1.0",
      elixir: "~> 1.14",
      compilers: [:build_dot_zig] ++ Mix.compilers(),
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
      {:build_dot_zig, "~> 0.1.0", runtime: false},
      {:zigler, github: "rbino/zigler", branch: "free-large-alloc", runtime: false},
      # Needed to make Zigler work
      {:ex_doc, "== 0.29.0", runtime: false, override: true},
      {:typed_struct, "~> 0.3.0"},
      {:elixir_uuid, "~> 1.2", only: :test},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end
end
