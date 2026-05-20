defmodule BotArmyYoutubeManager.Handlers.AnalyticsHandler do
  @moduledoc """
  Handles youtube.analytics.fetch requests to collect and store YouTube channel metrics.
  Detects anomalies and publishes alerts.
  """

  require Logger
  alias BotArmyYoutubeManager.Analytics.{Collector, AnomalyDetector}

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
    with {:ok, stored_metrics} <- Collector.collect_daily_metrics(),
         {:ok, anomalies} <- AnomalyDetector.detect_anomalies(stored_metrics) do
      Logger.info("Analytics collected and stored", metric_count: length(stored_metrics))

      if length(anomalies) > 0 do
        publish_anomaly_alerts(anomalies)
      end

      {:ok,
       %{
         event_id: generate_event_id(),
         timestamp: DateTime.utc_now(),
         metrics_stored: length(stored_metrics),
         anomalies_detected: length(anomalies),
         status: "collected",
         sample_metrics: Enum.take(stored_metrics, 5),
         anomalies: anomalies
       }}
    end
  end

  defp publish_anomaly_alerts(anomalies) do
    anomalies
    |> Enum.map(fn {type, reason, severity} ->
      Logger.warn("Anomaly detected: #{type} (#{severity}) - #{reason}")

      %{
        "event_type" => "anomaly",
        "anomaly_type" => type,
        "severity" => severity,
        "message" => reason,
        "timestamp" => DateTime.utc_now()
      }
    end)
  end

  defp generate_event_id do
    UUID.uuid4()
  end
end
