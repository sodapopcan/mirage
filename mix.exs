defmodule Mirage.MixProject do
  use Mix.Project

  def project do
    [
      app: :mirage,
      version: "0.0.4",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:leex] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [plt_add_apps: [:ex_unit]],

      # Hex
      description: "Test framework for the Hologram web framework",
      package: package(),

      # Docs
      name: "Mirage",
      source_url: "https://github.com/sodapopcan/mirage",
      homepage_url: "https://github.com/sodapopcan/mirage",
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  # The :hologram OTP app starts automatically under `mix test` and its
  # `PageDigestRegistry` refuses to boot unless a `page_digest.plt` file
  # exists at `<build>/lib/hologram/priv/page_digest.plt`. That file is
  # normally produced by `mix compile.hologram`, which requires a working
  # `npm install`. To let the test suite boot without the full asset
  # pipeline, we write an empty PLT (an erlang-term-encoded empty map) to
  # that path before `mix test` runs if one isn't already there.
  defp aliases do
    [
      test: [&ensure_page_digest_plt/1, "test"],
      lint: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "sobelow",
        "dialyzer",
        "test"
      ]
    ]
  end

  defp ensure_page_digest_plt(_args) do
    path =
      Path.join([Mix.Project.build_path(), "lib", "hologram", "priv", "page_digest.plt"])

    unless File.exists?(path) do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, :erlang.term_to_binary(%{}))
    end
  end

  def cli do
    [preferred_envs: [lint: :test]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      licenses: ["MIT", "Apache-2.0"],
      links: %{"GitHub" => "https://github.com/sodapopcan/mirage"},
      files: ~w(lib src .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:hologram, "~> 0.8"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},
      {:sobelow, "~> 0.14.1", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
