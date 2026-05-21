defmodule BotArmyYoutubeManager.Repo.Migrations.AddHeartbeatIdDefault do
  use Ecto.Migration

  @doc """
  The heartbeats table was created without a default UUID generator for the id column.
  Raw SQL INSERTs (used by BotArmy.Heartbeat.do_persist/4) fail because id is NOT NULL.
  This migration adds a database-level default so the column self-populates on insert.
  """

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"")

    execute("""
    ALTER TABLE heartbeats
    ALTER COLUMN id SET DEFAULT uuid_generate_v4()
    """)
  end

  def down do
    execute("""
    ALTER TABLE heartbeats
    ALTER COLUMN id DROP DEFAULT
    """)
  end
end
