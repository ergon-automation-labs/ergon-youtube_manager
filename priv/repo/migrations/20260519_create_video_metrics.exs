defmodule BotArmyYoutubeManager.Repo.Migrations.CreateVideoMetrics do
  use Ecto.Migration

  def change do
    create table(:video_metrics, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:video_id, :string, null: false)
      add(:date, :date, null: false)

      # Performance metrics
      add(:views, :integer, default: 0)
      add(:watch_time_minutes, :float, default: 0.0)
      add(:average_view_duration_seconds, :float, default: 0.0)
      add(:click_through_rate, :float, default: 0.0)

      # Engagement (JSON for flexibility)
      add(:engagement, :jsonb, default: "{'likes': 0, 'comments': 0, 'shares': 0, 'saves': 0}")

      # Traffic sources (JSON for flexibility)
      add(:traffic_sources, :jsonb,
        default: "{'search': 0, 'browse': 0, 'suggested': 0, 'direct': 0, 'other': 0}"
      )

      # Subscriber changes
      add(:subscriber_change, :integer, default: 0)

      # Raw API response (for debugging/audit)
      add(:raw_response, :jsonb, default: "{}")

      timestamps()
    end

    create(unique_index(:video_metrics, [:video_id, :date]))
  end
end
