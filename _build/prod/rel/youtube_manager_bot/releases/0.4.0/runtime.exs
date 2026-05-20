import Config

# Configure ecto repos for migrations and schema generation
config :bot_army_youtube_manager, ecto_repos: [BotArmyYoutubeManager.Repo]

# Read database config from environment (set by Salt via /etc/bot_army/youtube_manager_bot.env)
config :bot_army_youtube_manager, BotArmyYoutubeManager.Repo,
  username: System.get_env("DB_USER") || "postgres",
  password: System.get_env("DB_PASS") || "postgres",
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "35432"),
  database: System.get_env("DB_NAME") || "youtube_manager_prod",
  ssl: String.to_atom(System.get_env("DB_SSL") || "false"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10")

# Read OAuth config from environment (set by Salt)
config :bot_army_youtube_manager,
  oauth_client_id: System.get_env("YOUTUBE_OAUTH_CLIENT_ID"),
  oauth_client_secret: System.get_env("YOUTUBE_OAUTH_CLIENT_SECRET"),
  oauth_redirect_uri:
    System.get_env("YOUTUBE_OAUTH_REDIRECT_URI") || "http://localhost:8888/oauth/callback"
