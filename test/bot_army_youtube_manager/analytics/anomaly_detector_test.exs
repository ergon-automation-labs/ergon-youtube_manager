defmodule BotArmyYoutubeManager.Analytics.AnomalyDetectorTest do
  use ExUnit.Case
  @moduletag :handlers

  alias BotArmyYoutubeManager.Analytics.AnomalyDetector

  describe "detect_anomalies/1" do
    test "returns empty list for normal metrics" do
      metrics = [
        %{views: 100, watch_time_minutes: 50, click_through_rate: 0.05},
        %{views: 105, watch_time_minutes: 52, click_through_rate: 0.05},
        %{views: 102, watch_time_minutes: 51, click_through_rate: 0.05}
      ]

      {:ok, anomalies} = AnomalyDetector.detect_anomalies(metrics)
      assert anomalies == []
    end

    test "detects significant view drop" do
      metrics = [
        %{views: 100, watch_time_minutes: 50, click_through_rate: 0.05},
        %{views: 105, watch_time_minutes: 52, click_through_rate: 0.05},
        %{views: 102, watch_time_minutes: 51, click_through_rate: 0.05},
        %{views: 20, watch_time_minutes: 10, click_through_rate: 0.02}
      ]

      {:ok, anomalies} = AnomalyDetector.detect_anomalies(metrics)
      refute Enum.empty?(anomalies)
      assert Enum.any?(anomalies, fn {type, _reason, _severity} -> type == "view_drop" end)
    end

    test "returns ok for empty list" do
      {:ok, anomalies} = AnomalyDetector.detect_anomalies([])
      assert anomalies == []
    end

    test "returns ok for list with less than 3 items" do
      metrics = [
        %{views: 100, watch_time_minutes: 50, click_through_rate: 0.05}
      ]

      {:ok, anomalies} = AnomalyDetector.detect_anomalies(metrics)
      assert anomalies == []
    end
  end
end
