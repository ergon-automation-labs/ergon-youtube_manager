import Config

# For dev, default database is local postgres (via launchd port-forward on 35432)
config :bot_army_youtube_manager, BotArmyYoutubeManager.Repo,
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASS") || "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "35432"),
  database: "youtube_manager_dev",
  stacktrace: true,
  show_sensitive_data_on_error: true,
  pool_size: 10

# OAuth 2.0 redirect URI for local development
# Change this to match your local setup (e.g., http://localhost:5000/oauth/callback)
config :bot_army_youtube_manager,
  oauth_redirect_uri:
    System.get_env("YOUTUBE_OAUTH_REDIRECT_URI") || "http://localhost:8888/oauth/callback"
