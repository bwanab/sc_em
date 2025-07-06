defmodule ScEm.MixProject do
  use Mix.Project

  def project do
    [
      app: :sc_em,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ScEm, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:libgraph, "~> 0.7"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:music_build, github: "bwanab/music_build"},
      {:midi_in, path: "../midi_in"}
    ]
  end
end
