defmodule BotArmyYoutubeManager.Release do
  @moduledoc """
  Release tasks for the YouTube Manager bot.

  Migrations are run via the shared BotArmyLibraryRuntime.Ecto.MigrationRunner:

      /path/to/youtube_manager_bot/bin/youtube_manager_bot eval 'BotArmyYoutubeManager.Release.migrate()'

  Called from Salt during bot deployment, before the bot starts.
  """

  @app :bot_army_youtube_manager

  def migrate do
    BotArmyLibraryRuntime.Ecto.MigrationRunner.run(
      repo_module: BotArmyYoutubeManager.Repo,
      app_module: @app
    )
  end
end
