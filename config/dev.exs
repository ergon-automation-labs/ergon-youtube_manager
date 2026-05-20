import Config

# For dev, default database is local postgres
config :bot_army_youtube_manager, BotArmyYoutubeManager.Repo,
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASS") || "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  database: "youtube_manager_dev",
  stacktrace: true,
  show_sensitive_data_on_error: true,
  pool_size: 10
