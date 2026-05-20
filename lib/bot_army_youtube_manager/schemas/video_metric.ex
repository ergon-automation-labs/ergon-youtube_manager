defmodule BotArmyYoutubeManager.Schemas.VideoMetric do
  @moduledoc """
  YouTube video performance metrics stored daily.

  Fields like engagement and traffic_sources are stored as JSONB
  so they can evolve without requiring schema migrations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "video_metrics" do
    field(:video_id, :string)
    field(:date, :date)

    # Performance metrics
    field(:views, :integer, default: 0)
    field(:watch_time_minutes, :float, default: 0.0)
    field(:average_view_duration_seconds, :float, default: 0.0)
    field(:click_through_rate, :float, default: 0.0)

    # Engagement (JSON for flexibility)
    field(:engagement, :map,
      default: %{
        "likes" => 0,
        "comments" => 0,
        "shares" => 0,
        "saves" => 0
      }
    )

    # Traffic sources (JSON for flexibility)
    field(:traffic_sources, :map,
      default: %{
        "search" => 0.0,
        "browse" => 0.0,
        "suggested" => 0.0,
        "direct" => 0.0,
        "other" => 0.0
      }
    )

    # Subscriber changes
    field(:subscriber_change, :integer, default: 0)

    # Raw API response (for debugging/audit)
    field(:raw_response, :map, default: %{})

    timestamps()
  end

  @doc false
  def changeset(video_metric, attrs) do
    video_metric
    |> cast(attrs, [
      :video_id,
      :date,
      :views,
      :watch_time_minutes,
      :average_view_duration_seconds,
      :click_through_rate,
      :engagement,
      :traffic_sources,
      :subscriber_change,
      :raw_response
    ])
    |> validate_required([:video_id, :date])
    |> unique_constraint([:video_id, :date], name: :video_metrics_video_id_date_index)
  end
end
