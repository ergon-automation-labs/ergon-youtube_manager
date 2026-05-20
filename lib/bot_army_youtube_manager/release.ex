defmodule BotArmyYoutubeManager.Release do
  @moduledoc """
  Release management functions for deployment tasks.
  """

  require Logger

  def prepare do
    load_app()
    migrate()
  end

  defp load_app do
    Application.ensure_all_started(:bot_army_youtube_manager)
  end

  defp migrate do
    {:ok, _} = Application.ensure_all_started(:ecto_sql)

    repos = Application.fetch_env!(:bot_army_youtube_manager, :ecto_repos)

    Enum.each(repos, &migrate_repo/1)
  end

  defp migrate_repo(repo) do
    app = Keyword.fetch!(repo.__adapter__.__info__(:attributes), :app)
    migrations_path = Path.join([priv_dir(app), "repo", "migrations"])

    opts = [all: true]

    {:ok, _fun, _apps} =
      Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, migrations_path, :up, opts))
  end

  defp priv_dir(app), do: Path.join([Application.app_dir(app), "priv"])
end
