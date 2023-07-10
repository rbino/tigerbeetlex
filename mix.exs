defmodule TigerBeetlex.MixProject do
  use Mix.Project

  def project do
    [
      app: :tigerbeetlex,
      version: "0.1.0",
      elixir: "~> 1.14",
      install_zig: "0.9.1",
      zig_executable: "scripts/build.sh",
      zig_build_mode: zig_build_mode(Mix.env()),
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

  defp zig_build_mode(:prod), do: :release_safe
  defp zig_build_mode(_env), do: :debug

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, "~> 1.0"},
      {:build_dot_zig, "~> 0.2.0", runtime: false},
      {:zigler, github: "rbino/zigler", branch: "free-large-alloc", runtime: false},
      # Needed to make Zigler work
      {:ex_doc, "== 0.29.0", runtime: false, override: true},
      {:typed_struct, "~> 0.3.0"},
      {:elixir_uuid, "~> 1.2", only: :test},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false}
    ]
  end
end
