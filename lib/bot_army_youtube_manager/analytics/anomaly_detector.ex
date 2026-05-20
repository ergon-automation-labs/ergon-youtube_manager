defmodule BotArmyYoutubeManager.Analytics.AnomalyDetector do
  @moduledoc """
  Detects anomalies in YouTube analytics metrics.

  Uses statistical methods (standard deviation, trend analysis) to identify
  significant drops in views, engagement, or other metrics.
  """

  require Logger

  def detect_anomalies(metrics) when is_list(metrics) and length(metrics) > 0 do
    anomalies = []
    anomalies = check_view_drops(metrics, anomalies)
    anomalies = check_engagement_drops(metrics, anomalies)
    anomalies = check_ctr_drops(metrics, anomalies)

    if Enum.empty?(anomalies) do
      {:ok, []}
    else
      {:ok, anomalies}
    end
  end

  def detect_anomalies(_), do: {:ok, []}

  def detect_anomalies_per_video(metrics) when is_list(metrics) and length(metrics) > 0 do
    metrics
    |> Enum.group_by(& &1.video_id)
    |> Enum.flat_map(fn {video_id, video_metrics} ->
      anomalies = []
      anomalies = check_view_drops(video_metrics, anomalies)
      anomalies = check_engagement_drops(video_metrics, anomalies)
      anomalies = check_ctr_drops(video_metrics, anomalies)

      Enum.map(anomalies, fn {type, reason, severity} ->
        {type, reason, severity, video_id}
      end)
    end)
  end

  def detect_anomalies_per_video(_), do: []

  defp check_view_drops(metrics, anomalies) do
    views = metrics |> Enum.map(&Map.get(&1, :views, 0)) |> Enum.filter(&(&1 > 0))

    case analyze_trend(views, "views") do
      {:anomaly, reason, severity} ->
        [{"view_drop", reason, severity} | anomalies]

      :normal ->
        anomalies
    end
  end

  defp check_engagement_drops(metrics, anomalies) do
    watch_times =
      metrics |> Enum.map(&Map.get(&1, :watch_time_minutes, 0)) |> Enum.filter(&(&1 > 0))

    case analyze_trend(watch_times, "watch_time") do
      {:anomaly, reason, severity} ->
        [{"engagement_drop", reason, severity} | anomalies]

      :normal ->
        anomalies
    end
  end

  defp check_ctr_drops(metrics, anomalies) do
    ctrs = metrics |> Enum.map(&Map.get(&1, :click_through_rate, 0)) |> Enum.filter(&(&1 > 0))

    case analyze_trend(ctrs, "ctr") do
      {:anomaly, reason, severity} ->
        [{"ctr_drop", reason, severity} | anomalies]

      :normal ->
        anomalies
    end
  end

  defp analyze_trend(values, _metric_name) when length(values) < 3 do
    :normal
  end

  defp analyze_trend(values, metric_name) do
    mean = Enum.sum(values) / length(values)
    variance = variance(values, mean)
    std_dev = :math.sqrt(variance)

    # If any recent value is more than 2 std devs below mean, flag as anomaly
    last_value = List.last(values)
    z_score = (last_value - mean) / (std_dev + 0.001)

    cond do
      z_score < -2.0 ->
        percent_drop = ((mean - last_value) / mean * 100) |> Float.round(1)
        {:anomaly, "#{metric_name} dropped #{percent_drop}% below average", :high}

      z_score < -1.5 ->
        percent_drop = ((mean - last_value) / mean * 100) |> Float.round(1)
        {:anomaly, "#{metric_name} dropped #{percent_drop}% below average", :medium}

      true ->
        :normal
    end
  end

  defp variance(values, mean) do
    sum_sq_diffs = Enum.reduce(values, 0, fn x, acc -> acc + (x - mean) ** 2 end)
    sum_sq_diffs / length(values)
  end
end
