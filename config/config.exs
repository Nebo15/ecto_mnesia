use Mix.Config

config :ex_unit, capture_log: true

# TODO remove this
config :ecto_mnesia,
  ecto_repos: [TestRepo]

config :ecto_mnesia, TestRepo,
  adapter: Ecto.Adapters.Mnesia
# END

:erlang.system_flag(:backtrace_depth, 1000)
