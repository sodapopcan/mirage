defmodule Holography.MixProject do
  use Mix.Project

  def project do
    [
      app: :holography,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Docs
      name: "Holography",
      source_url: "https://github.com/sodapopcan/holography",
      docs: [
        main: "readme",
        extras: ["README.md"]
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
      test: [&ensure_page_digest_plt/1, "test"]
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:hologram, "~> 0.8"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},
      {:meeseeks, "~> 0.18.0"}
    ]
  end
end
