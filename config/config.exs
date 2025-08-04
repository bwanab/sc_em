# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
config :sc_em,
  #port: 57110,
  port: String.to_integer(System.get_env("SC_PORT", "57110")),
  ip: String.split(System.get_env("SC_IP", "127.0.0.1"), ".") |> Enum.map(&(String.to_integer(&1))) |> List.to_tuple,
  remote_synth_dir: System.get_env("MODSYNTH_REMOTE_DIR", Path.expand("~/.modsynth/synthdefs")),
  local_synth_dir: System.get_env("MODSYNTH_LOCAL_DIR", Path.expand("~/.modsynth/synthdefs"))

#
# And access this configuration in your application as:
#
#     Application.get_env(:log_server, :key)
#
# Or configure a 3rd-party app:
#
config :logger, :default_handler,
  level: :info,
  format: "[$level] $messge $metadata\n",
  metadata: [:file, :line]

config :logger,
  compile_time_application: :sc_em
