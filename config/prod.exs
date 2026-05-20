import Config

# Production database configuration (real Kubernetes PostgreSQL on Air node)
config :bot_army_youtube_manager, BotArmyYoutubeManager.Repo,
  username: "postgres",
  password: System.get_env("DB_PASS") || "",
  hostname: System.get_env("DB_HOST") || "postgres.default.svc.cluster.local",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  database: "youtube_manager_prod",
  stacktrace: false,
  show_sensitive_data_on_error: false,
  pool_size: 20

# OAuth 2.0 configuration (set by Salt state)
config :bot_army_youtube_manager,
  oauth_redirect_uri:
    System.get_env("YOUTUBE_OAUTH_REDIRECT_URI") || "http://air.internal/oauth/callback"
