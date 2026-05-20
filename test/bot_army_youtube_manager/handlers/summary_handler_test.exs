defmodule BotArmyYoutubeManager.Handlers.SummaryHandlerTest do
  use ExUnit.Case
  @moduletag :handlers

  alias BotArmyYoutubeManager.Handlers.SummaryHandler

  describe "handle/2" do
    test "returns success with summary ready for PARA" do
      payload = %{}

      {:ok, result} = SummaryHandler.handle(payload, %{})

      assert result.status == "ready_for_para"
      assert is_binary(result.event_id)
      assert result.timestamp
      assert is_binary(result.markdown)
      assert String.contains?(result.para_path, "weekly_summaries/")
    end

    test "generates markdown summary with proper formatting" do
      payload = %{}

      {:ok, result} = SummaryHandler.handle(payload, %{})

      # Verify markdown contains expected sections
      assert String.contains?(result.markdown, "Weekly YouTube Summary")
      assert String.contains?(result.markdown, "Total Views")
      assert String.contains?(result.markdown, "Engagement")
      assert String.contains?(result.markdown, "Traffic Sources")
    end

    test "includes summary structure with metrics aggregation" do
      payload = %{}

      {:ok, result} = SummaryHandler.handle(payload, %{})

      summary = result.summary

      # Verify summary has expected fields
      assert Map.has_key?(summary, :period)
      assert Map.has_key?(summary, :metrics_count)
      assert Map.has_key?(summary, :total_views)
      assert Map.has_key?(summary, :total_watch_time)
      assert Map.has_key?(summary, :engagement_summary)
      assert Map.has_key?(summary, :traffic_breakdown)
      assert Map.has_key?(summary, :trends)

      # Verify engagement summary
      assert Map.has_key?(summary.engagement_summary, :total_likes)
      assert Map.has_key?(summary.engagement_summary, :total_comments)
      assert Map.has_key?(summary.engagement_summary, :total_shares)

      # Verify metrics are aggregated (with no data, they should be 0)
      assert summary.metrics_count == 0
      assert summary.total_views == 0
      assert summary.total_watch_time == 0.0
    end
  end
end
