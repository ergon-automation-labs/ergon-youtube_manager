import Config

# Configure logging
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configure Ecto
config :bot_army_youtube_manager,
  ecto_repos: [BotArmyYoutubeManager.Repo]

# Import environment-specific config
import_config "#{config_env()}.exs"
