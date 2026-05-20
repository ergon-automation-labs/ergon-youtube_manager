import Config

# For test, use an in-memory SQLite database or a separate test database
config :bot_army_youtube_manager, BotArmyYoutubeManager.Repo,
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASS") || "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  database: "youtube_manager_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1
