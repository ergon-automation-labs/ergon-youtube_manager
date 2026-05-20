import Config

# Configure logging
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configure Ecto
config :bot_army_youtube_manager,
  ecto_repos: [BotArmyYoutubeManager.Repo]

# OAuth 2.0 Configuration (YouTube Analytics API)
# Required env vars:
# - YOUTUBE_OAUTH_CLIENT_ID: OAuth 2.0 Client ID from Google Cloud Console
# - YOUTUBE_OAUTH_CLIENT_SECRET: OAuth 2.0 Client Secret
# - YOUTUBE_OAUTH_ACCESS_TOKEN: Access token (obtained via initial authorization)
# - YOUTUBE_OAUTH_REFRESH_TOKEN: Refresh token (for token refresh)
# Optional:
# - YOUTUBE_OAUTH_REDIRECT_URI: Custom redirect URI (default: http://localhost:8080/oauth/callback)

config :bot_army_youtube_manager,
  oauth_client_id: System.get_env("YOUTUBE_OAUTH_CLIENT_ID"),
  oauth_client_secret: System.get_env("YOUTUBE_OAUTH_CLIENT_SECRET"),
  oauth_redirect_uri:
    System.get_env("YOUTUBE_OAUTH_REDIRECT_URI") || "http://localhost:8080/oauth/callback"

# Import environment-specific config
import_config "#{config_env()}.exs"
