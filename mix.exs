defmodule ScEm.MixProject do
  use Mix.Project

  def project do
    [
      app: :sc_em,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: [:portmidi, :jason, :music_prims],
      extra_applications: [:logger],
      mod: {ScEm, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"},
      {:portmidi, git: "https://github.com/bwanab/ex-portmidi.git"},
      {:music_prims, path: "/Users/williamallen/src/music_prims"}
    ]
  end
end
