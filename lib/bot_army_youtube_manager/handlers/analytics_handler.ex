defmodule BotArmyYoutubeManager.Handlers.AnalyticsHandler do
  @moduledoc """
  Handles youtube.analytics.fetch requests to collect and store YouTube channel metrics.
  """

  require Logger
  alias BotArmyYoutubeManager.Youtube.ApiClient

  def handle(payload, _opts) do
    Logger.info("Processing analytics fetch request", payload: payload)

    case fetch_and_store_analytics(payload) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, "Analytics collection failed: #{reason}"}
    end
  end

  defp fetch_and_store_analytics(_payload) do
    # Fetch channel-level metrics
    with {:ok, channel_data} <- ApiClient.fetch_channel_metrics() do
      Logger.info("Analytics collected", video_count: length(channel_data.videos))

      {:ok,
       %{
         event_id: generate_event_id(),
         timestamp: DateTime.utc_now(),
         channel_metrics: channel_data,
         status: "collected",
         videos_analyzed: length(channel_data.videos)
       }}
    end
  end

  defp generate_event_id do
    UUID.uuid4()
  end
end
