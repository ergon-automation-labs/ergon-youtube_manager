defmodule BotArmyYoutubeManager.Handlers.AnalyticsHandler do
  @moduledoc """
  Handles youtube.analytics.fetch requests to collect and store YouTube channel metrics.
  """

  require Logger
  alias BotArmyYoutubeManager.Analytics.Collector

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
    with {:ok, stored_metrics} <- Collector.collect_daily_metrics() do
      Logger.info("Analytics collected and stored", metric_count: length(stored_metrics))

      {:ok,
       %{
         event_id: generate_event_id(),
         timestamp: DateTime.utc_now(),
         metrics_stored: length(stored_metrics),
         status: "collected",
         sample_metrics: Enum.take(stored_metrics, 5)
       }}
    end
  end

  defp generate_event_id do
    UUID.uuid4()
  end
end
