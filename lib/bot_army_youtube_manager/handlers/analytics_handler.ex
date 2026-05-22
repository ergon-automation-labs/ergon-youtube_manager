defmodule BotArmyYoutubeManager.Handlers.AnalyticsHandler do
  @moduledoc """
  Handles youtube.analytics.fetch requests to collect and store YouTube channel metrics.
  Detects anomalies and publishes alerts.
  """

  require Logger
  alias BotArmyYoutubeManager.Analytics.{Collector, AnomalyDetector}
  alias BotArmyYoutubeManager.Learning.{Recorder, ParaWriter}
  alias BotArmyYoutubeManager.Discord.Publisher

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
      anomalies_with_video = AnomalyDetector.detect_anomalies_per_video(stored_metrics)
      Logger.info("Analytics collected and stored", metric_count: length(stored_metrics))

      # Record all anomaly decisions for learning (fails gracefully if table doesn't exist)
      Enum.each(anomalies_with_video, fn {type, reason, severity, video_id} ->
        try do
          Recorder.record_decision(type, video_id, %{reason: reason, severity: severity})
        rescue
          _e ->
            Logger.warning(
              "[AnalyticsHandler] Failed to record anomaly decision for #{video_id}: #{type}"
            )
        end
      end)

      # Flatten for alert publishing (remove video_id)
      anomalies =
        Enum.map(anomalies_with_video, fn {type, reason, severity, _vid} ->
          {type, reason, severity}
        end)

      if length(anomalies) > 0 do
        publish_anomaly_alerts(anomalies)
        Publisher.publish_anomalies_to_discord(anomalies)
      end

      # Phase 3: write daily PARA summary (fails gracefully in test mode)
      today = Date.utc_today()

      para_path =
        try do
          write_daily_para_summary(today)
        rescue
          RuntimeError -> nil
        end

      {:ok,
       %{
         event_id: generate_event_id(),
         timestamp: DateTime.utc_now(),
         metrics_stored: length(stored_metrics),
         anomalies_detected: length(anomalies),
         status: "collected",
         sample_metrics: Enum.take(stored_metrics, 5),
         anomalies: anomalies,
         para_path: para_path
       }}
    end
  end

  defp write_daily_para_summary(date) do
    case ParaWriter.generate_para_summary(date, date) do
      {:ok, %{path: path, markdown: markdown}} ->
        case ParaWriter.write_to_para(path, markdown) do
          {:ok, written_path} ->
            written_path

          {:error, reason} ->
            Logger.warning("[AnalyticsHandler] PARA write failed: #{inspect(reason)}")
            nil
        end

      {:error, reason} ->
        Logger.warning("[AnalyticsHandler] PARA summary generation failed: #{inspect(reason)}")
        nil
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
