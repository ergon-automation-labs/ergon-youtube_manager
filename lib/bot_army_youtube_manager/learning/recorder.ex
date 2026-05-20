defmodule BotArmyYoutubeManager.Learning.Recorder do
  @moduledoc """
  Records anomaly detection decisions for learning and optimization.
  """

  require Logger
  alias BotArmyYoutubeManager.{Repo, Schemas.LearningOutcome}

  def record_decision(anomaly_type, video_id, decision_details) do
    attrs = %{
      item_id: video_id,
      category: "anomaly_detection",
      decision: anomaly_to_decision_string(anomaly_type, decision_details),
      recorded_at: DateTime.utc_now()
    }

    case Repo.insert(LearningOutcome.changeset(%LearningOutcome{}, attrs)) do
      {:ok, outcome} ->
        Logger.debug("Recorded anomaly decision for video #{video_id}: #{anomaly_type}")
        {:ok, outcome}

      {:error, reason} ->
        Logger.warning("Failed to record learning outcome for #{video_id}: #{inspect(reason)}")

        {:error, reason}
    end
  end

  def record_batch(anomalies, video_id) do
    results =
      Enum.map(anomalies, fn {anomaly_type, reason, severity} ->
        record_decision(anomaly_type, video_id, %{
          reason: reason,
          severity: severity
        })
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    case errors do
      [] -> {:ok, results}
      _ -> {:error, "Some anomalies failed to record"}
    end
  end

  defp anomaly_to_decision_string(anomaly_type, details) do
    reason = Map.get(details, :reason, "")
    severity = Map.get(details, :severity, "unknown")
    "#{anomaly_type}:#{severity}:#{reason}"
  end
end
