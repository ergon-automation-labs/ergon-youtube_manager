defmodule BotArmyYoutubeManager.Release do
  @moduledoc """
  Release management functions for deployment tasks.
  """

  require Logger

  def setup do
    load_app()
    create_database()
    migrate()
  end

  def migrate do
    load_app()
    {:ok, _} = Application.ensure_all_started(:ecto_sql)
    repos = Application.fetch_env!(:bot_army_youtube_manager, :ecto_repos)
    Enum.each(repos, &migrate_repo/1)
  end

  defp load_app do
    Application.ensure_all_started(:bot_army_youtube_manager)
  end

  defp create_database do
    {:ok, _} = Application.ensure_all_started(:ecto_sql)

    case Ecto.Adapters.Postgres.storage_up(BotArmyYoutubeManager.Repo.config()) do
      :ok -> Logger.info("Database created successfully")
      {:error, :already_up} -> Logger.info("Database already exists")
      {:error, reason} -> Logger.warning("Database creation failed: #{inspect(reason)}")
    end
  end

  defp migrate_repo(repo) do
    migrations_path =
      Path.join([Application.app_dir(:bot_army_youtube_manager), "priv", "repo", "migrations"])

    opts = [all: true]

    {:ok, _fun, _apps} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, migrations_path, :up, opts))
  end
end
