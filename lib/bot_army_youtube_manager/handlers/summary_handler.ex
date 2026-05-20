defmodule BotArmyYoutubeManager.Handlers.SummaryHandler do
  @moduledoc """
  Generates weekly YouTube performance summaries from stored metrics.
  Publishes summaries ready for PARA writing via para bot.
  """

  require Logger
  alias BotArmyYoutubeManager.Analytics.Collector
  alias BotArmyYoutubeManager.Learning.ParaWriter

  def handle(payload, _opts) do
    Logger.info("Processing weekly summary request", payload: payload)

    case generate_summary(payload) do
      {:ok, summary} ->
        {:ok, summary}

      {:error, reason} ->
        {:error, "Summary generation failed: #{reason}"}
    end
  end

  defp generate_summary(%{"start_date" => start_str, "end_date" => end_str}) do
    with {:ok, start_date} <- Date.from_iso8601(start_str),
         {:ok, end_date} <- Date.from_iso8601(end_str),
         metrics <- Collector.get_metrics_for_range(start_date, end_date) do
      generate_summary_from_metrics(metrics, start_date, end_date)
    end
  end

  defp generate_summary(_) do
    # Default to last 7 days
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -7)
    metrics = Collector.get_metrics_for_range(start_date, end_date)
    generate_summary_from_metrics(metrics, start_date, end_date)
  end

  defp generate_summary_from_metrics(metrics, start_date, end_date) do
    summary = %{
      period: "#{start_date} to #{end_date}",
      metrics_count: length(metrics),
      total_views: sum_field(metrics, :views),
      total_watch_time: sum_field(metrics, :watch_time_minutes),
      average_ctr: average_field(metrics, :click_through_rate),
      top_video: get_top_video(metrics),
      engagement_summary: summarize_engagement(metrics),
      traffic_breakdown: summarize_traffic(metrics),
      trends: detect_trends(metrics)
    }

    # Generate enhanced markdown with learning insights
    enhanced_result =
      try do
        ParaWriter.generate_para_summary(start_date, end_date)
      rescue
        _ ->
          # Fallback if ParaWriter encounters errors (like in test mode)
          {:error, "ParaWriter unavailable"}
      end

    case enhanced_result do
      {:ok, %{path: para_path, markdown: enhanced_markdown}} ->
        {:ok,
         %{
           event_id: generate_event_id(),
           timestamp: DateTime.utc_now(),
           summary: summary,
           markdown: enhanced_markdown,
           status: "ready_for_para",
           para_path: para_path
         }}

      {:error, _reason} ->
        # Fallback to basic markdown if learning system fails
        {:ok,
         %{
           event_id: generate_event_id(),
           timestamp: DateTime.utc_now(),
           summary: summary,
           markdown: format_summary_markdown(summary),
           status: "ready_for_para",
           para_path: "projects/Bot Army/YouTube Analytics/weekly_summaries/#{end_date}.md"
         }}
    end
  end

  defp sum_field(metrics, field) do
    Enum.reduce(metrics, 0, &(Map.get(&1, field, 0) + &2))
  end

  defp average_field(metrics, field) do
    case Enum.filter(metrics, &(Map.get(&1, field, 0) > 0)) do
      [] -> 0.0
      filtered -> sum_field(filtered, field) / length(filtered)
    end
  end

  defp get_top_video(metrics) do
    metrics
    |> Enum.sort_by(&Map.get(&1, :views, 0), :desc)
    |> Enum.at(0)
  end

  defp summarize_engagement(metrics) do
    total_engagement =
      Enum.reduce(metrics, %{}, fn metric, acc ->
        engagement = Map.get(metric, :engagement, %{})
        Map.merge(acc, engagement, fn _, v1, v2 -> v1 + (v2 || 0) end)
      end)

    %{
      total_likes: Map.get(total_engagement, "likes", 0),
      total_comments: Map.get(total_engagement, "comments", 0),
      total_shares: Map.get(total_engagement, "shares", 0)
    }
  end

  defp summarize_traffic(metrics) do
    traffic =
      Enum.reduce(metrics, %{}, fn metric, acc ->
        sources = Map.get(metric, :traffic_sources, %{})
        Map.merge(acc, sources, fn _, v1, v2 -> v1 + (v2 || 0) end)
      end)

    total = Enum.sum(Map.values(traffic))

    case total do
      0 -> %{}
      _ -> Map.new(traffic, fn {k, v} -> {k, Float.round(v / total * 100, 2)} end)
    end
  end

  defp detect_trends(metrics) when length(metrics) < 2, do: []

  defp detect_trends(metrics) do
    sorted = Enum.sort_by(metrics, & &1.date)

    Enum.zip(Enum.slice(sorted, 0..-2//1), Enum.slice(sorted, 1..-1//1))
    |> Enum.map(fn {prev, curr} ->
      view_change = curr.views - prev.views
      ctr_change = curr.click_through_rate - prev.click_through_rate

      case {view_change, ctr_change} do
        {change, _} when change > 100 -> "📈 Views spike (#{change} new views)"
        {change, _} when change < -100 -> "📉 Views dropped (#{change} views)"
        {_, change} when change > 0.5 -> "⬆️ CTR increased"
        {_, change} when change < -0.5 -> "⬇️ CTR decreased"
        _ -> nil
      end
    end)
    |> Enum.filter(&(not is_nil(&1)))
  end

  defp format_summary_markdown(summary) do
    """
    # Weekly YouTube Summary: #{summary.period}

    ## Overview
    - Total Views: #{summary.total_views}
    - Total Watch Time: #{summary.total_watch_time |> to_float() |> Float.round(2)} minutes
    - Average CTR: #{summary.average_ctr |> to_float() |> Float.round(4)}%
    - Videos Analyzed: #{summary.metrics_count}

    ## Top Video
    #{if summary.top_video do
      "- #{summary.top_video.video_id}: #{summary.top_video.views} views"
    else
      "No videos analyzed"
    end}

    ## Engagement
    - Likes: #{summary.engagement_summary.total_likes}
    - Comments: #{summary.engagement_summary.total_comments}
    - Shares: #{summary.engagement_summary.total_shares}

    ## Traffic Sources
    #{Enum.map(summary.traffic_breakdown, fn {source, pct} -> "- #{source}: #{pct}%" end) |> Enum.join("\n")}

    ## Trends Detected
    #{if Enum.empty?(summary.trends) do
      "No significant trends this period"
    else
      Enum.join(summary.trends, "\n")
    end}
    """
  end

  defp generate_event_id do
    UUID.uuid4()
  end

  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value / 1.0
end
