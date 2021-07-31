defmodule ViaJoystick.MixProject do
  use Mix.Project

  def project do
    [
      app: :via_joystick,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
       {:joystick,
       path: "/home/ubuntu/Documents/Github/cp-elixir/libraries/joystick"},
       {:via_utils, path: "/home/ubuntu/Documents/Github/cp-elixir/libraries/via-utils/"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end