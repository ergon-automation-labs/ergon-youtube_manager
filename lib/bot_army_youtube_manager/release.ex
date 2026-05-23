defmodule BotArmyYoutubeManager.Release do
  @moduledoc """
  Release management functions for deployment tasks.

  Migrations are run via the shared BotArmyRuntime.Ecto.MigrationRunner:

      /path/to/youtube_manager/bin/youtube_manager eval 'BotArmyYoutubeManager.Release.migrate()'

  Called from Salt during bot deployment, before the bot starts.
  """

  alias BotArmyRuntime.Ecto.MigrationRunner

  def migrate do
    MigrationRunner.run(
      repo_module: BotArmyYoutubeManager.Repo,
      app_module: :bot_army_youtube_manager
    )
  end
end
