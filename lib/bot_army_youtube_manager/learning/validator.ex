defmodule BotArmyYoutubeManager.Learning.Validator do
  @moduledoc """
  Validates anomaly detection decisions by comparing predictions against actual outcomes.

  Checks decisions recorded 7-14 days ago against current metrics to determine if predictions
  were correct (e.g., did a flagged view drop actually recover).
  """

  require Logger
  import Ecto.Query
  alias BotArmyYoutubeManager.{Repo, Schemas.LearningOutcome, Schemas.VideoMetric}

  @validation_window_days 7..14

  def validate_pending_decisions do
    Logger.info("Starting validation of pending anomaly decisions")

    pending_outcomes = fetch_pending_outcomes()
    Logger.info("Found #{length(pending_outcomes)} pending outcomes to validate")

    results =
      Enum.map(pending_outcomes, fn outcome ->
        validate_outcome(outcome)
      end)

    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

    Logger.info("Validation complete: #{length(successes)} validated, #{length(failures)} failed")

    {:ok, %{validated: length(successes), failed: length(failures)}}
  end

  defp fetch_pending_outcomes do
    days_ago_start = Date.utc_today() |> Date.add(-Enum.max(@validation_window_days))
    days_ago_end = Date.utc_today() |> Date.add(-Enum.min(@validation_window_days))

    from(lo in LearningOutcome,
      where:
        is_nil(lo.was_correct) and lo.recorded_at >= ^days_ago_start and
          lo.recorded_at <= ^days_ago_end,
      order_by: [lo.recorded_at]
    )
    |> Repo.all()
  end

  defp validate_outcome(outcome) do
    case check_outcome_accuracy(outcome) do
      {:ok, was_correct, actual_result} ->
        update_outcome(outcome, was_correct, actual_result)

      {:error, reason} ->
        Logger.warning("Could not validate outcome #{outcome.id}: #{reason}")

        {:error, reason}
    end
  end

  defp check_outcome_accuracy(outcome) do
    case parse_decision(outcome.decision) do
      {:ok, anomaly_type, reason, severity} ->
        check_anomaly_type(anomaly_type, outcome.item_id, outcome.recorded_at, reason, severity)

      {:error, reason} ->
        {:error, "Could not parse decision: #{reason}"}
    end
  end

  defp check_anomaly_type("view_drop", video_id, recorded_at, reason, severity) do
    check_recovery(video_id, recorded_at, :views, reason, severity)
  end

  defp check_anomaly_type("engagement_drop", video_id, recorded_at, reason, severity) do
    check_recovery(video_id, recorded_at, :engagement, reason, severity)
  end

  defp check_anomaly_type("ctr_drop", video_id, recorded_at, reason, severity) do
    check_recovery(video_id, recorded_at, :ctr, reason, severity)
  end

  defp check_anomaly_type(type, _video_id, _recorded_at, _reason, _severity) do
    {:error, "Unknown anomaly type: #{type}"}
  end

  defp check_recovery(video_id, recorded_at, metric_type, reason, severity) do
    # Get metrics from the time of the anomaly
    anomaly_date = DateTime.to_date(recorded_at)

    # Get metrics from 7 days after (to see if recovery happened)
    recovery_date = Date.add(anomaly_date, 7)

    with {:ok, anomaly_metric} <- fetch_metric(video_id, anomaly_date),
         {:ok, recovery_metric} <- fetch_metric(video_id, recovery_date) do
      was_correct = evaluate_recovery(metric_type, anomaly_metric, recovery_metric, severity)

      result_reason =
        describe_outcome(metric_type, anomaly_metric, recovery_metric, reason, severity)

      {:ok, was_correct, result_reason}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_metric(video_id, date) do
    case Repo.get_by(VideoMetric, video_id: video_id, date: date) do
      nil -> {:error, "No metric found for #{video_id} on #{date}"}
      metric -> {:ok, metric}
    end
  end

  defp evaluate_recovery(:views, anomaly_metric, recovery_metric, severity) do
    threshold = recovery_threshold(:views, severity)
    anomaly_metric.views > 0 and recovery_metric.views / anomaly_metric.views > threshold
  end

  defp evaluate_recovery(:engagement, anomaly_metric, recovery_metric, severity) do
    threshold = recovery_threshold(:engagement, severity)

    anomaly_engagement =
      Map.get(anomaly_metric.engagement, "comments", 0) +
        Map.get(anomaly_metric.engagement, "likes", 0)

    recovery_engagement =
      Map.get(recovery_metric.engagement, "comments", 0) +
        Map.get(recovery_metric.engagement, "likes", 0)

    anomaly_engagement > 0 and recovery_engagement / anomaly_engagement > threshold
  end

  defp evaluate_recovery(:ctr, anomaly_metric, recovery_metric, severity) do
    threshold = recovery_threshold(:ctr, severity)

    anomaly_metric.click_through_rate > 0 and
      recovery_metric.click_through_rate / anomaly_metric.click_through_rate > threshold
  end

  defp recovery_threshold(metric_type, severity) do
    case {metric_type, severity} do
      {:views, "high"} -> 1.15
      {:views, "medium"} -> 1.10
      {:views, _} -> 1.05
      {:engagement, "high"} -> 1.10
      {:engagement, "medium"} -> 1.05
      {:engagement, _} -> 1.02
      {:ctr, "high"} -> 1.10
      {:ctr, "medium"} -> 1.05
      {:ctr, _} -> 1.02
    end
  end

  defp describe_outcome(:views, anomaly, recovery, reason, severity) do
    percent_change =
      ((recovery.views - anomaly.views) / anomaly.views * 100) |> Float.round(1)

    threshold = recovery_threshold(:views, severity)

    "Prediction(#{severity}): #{reason} | Recovery: #{anomaly.views} → #{recovery.views} (#{percent_change}%, threshold: #{(threshold - 1) * 100}%)"
  end

  defp describe_outcome(:engagement, anomaly, recovery, reason, severity) do
    anomaly_eng =
      Map.get(anomaly.engagement, "comments", 0) +
        Map.get(anomaly.engagement, "likes", 0)

    recovery_eng =
      Map.get(recovery.engagement, "comments", 0) +
        Map.get(recovery.engagement, "likes", 0)

    percent_change = ((recovery_eng - anomaly_eng) / max(anomaly_eng, 1) * 100) |> Float.round(1)
    threshold = recovery_threshold(:engagement, severity)

    "Prediction(#{severity}): #{reason} | Recovery: #{anomaly_eng} → #{recovery_eng} (#{percent_change}%, threshold: #{(threshold - 1) * 100}%)"
  end

  defp describe_outcome(:ctr, anomaly, recovery, reason, severity) do
    percent_change =
      ((recovery.click_through_rate - anomaly.click_through_rate) /
         max(anomaly.click_through_rate, 0.001) * 100)
      |> Float.round(1)

    threshold = recovery_threshold(:ctr, severity)

    "Prediction(#{severity}): #{reason} | Recovery: #{anomaly.click_through_rate}% → #{recovery.click_through_rate}% (#{percent_change}%, threshold: #{(threshold - 1) * 100}%)"
  end

  defp parse_decision(decision_string) do
    parts = String.split(decision_string, ":")

    case parts do
      [anomaly_type, severity, reason] ->
        {:ok, anomaly_type, reason, severity}

      _ ->
        {:error, "Could not parse decision string: #{decision_string}"}
    end
  end

  defp update_outcome(outcome, was_correct, actual_result) do
    case Repo.update(
           LearningOutcome.changeset(outcome, %{
             was_correct: was_correct,
             actual_result: actual_result
           })
         ) do
      {:ok, updated} ->
        Logger.debug("Updated outcome #{outcome.id}: was_correct=#{was_correct}")

        {:ok, updated}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
