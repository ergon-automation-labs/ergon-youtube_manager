import Config

# Configure database
config :bot_army_youtube_manager, BotArmyYoutubeManager.Repo,
  url: System.get_env("DATABASE_URL") || "postgresql://localhost/youtube_manager_dev",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: [:binary, packet: :raw, active: false, exit_on_close: true]

# YouTube API configuration
config :bot_army_youtube_manager,
  youtube_api_key: System.get_env("YOUTUBE_API_KEY")
