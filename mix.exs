defmodule TigerBeetlex.MixProject do
  use Mix.Project

  @version "0.16.41"

  @repo_url "https://github.com/rbino/tigerbeetlex"

  def project do
    [
      app: :tigerbeetlex,
      version: @version,
      elixir: "~> 1.14",
      install_zig: "0.13.0",
      zig_build_mode: zig_build_mode(Mix.env()),
      compilers: [:build_dot_zig] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: [
        main: "walkthrough",
        source_ref: @version,
        source_url: @repo_url,
        groups_for_modules: [
          "Message based API": [TigerBeetlex.Client, TigerBeetlex.Response],
          "Blocking API": [TigerBeetlex.Connection],
          "Data structures": [
            TigerBeetlex.Account,
            TigerBeetlex.AccountBalance,
            TigerBeetlex.AccountFilter,
            TigerBeetlex.AccountFilterFlags,
            TigerBeetlex.AccountFlags,
            TigerBeetlex.CreateAccountsResult,
            TigerBeetlex.CreateTransfersResult,
            TigerBeetlex.QueryFilter,
            TigerBeetlex.QueryFilterFlags,
            TigerBeetlex.Transfer,
            TigerBeetlex.TransferFlags
          ],
          Utilities: [TigerBeetlex.ID],
          Types: [TigerBeetlex.Types]
        ],
        extras: ["guides/walkthrough.livemd"],
        groups_for_extras: [Introduction: ~r/guides/]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {TigerBeetlex.Application, []},
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
      maintainers: ["Riccardo Binetti"],
      files: ~w(lib src tools .formatter.exs mix.exs README* LICENSE*
                CHANGELOG* build.zig build.zig.zon),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
