defmodule BotArmyYoutubeManager.Handlers.AnalyticsHandlerTest do
  use ExUnit.Case
  @moduletag :handlers

  alias BotArmyYoutubeManager.Handlers.AnalyticsHandler

  describe "handle/2" do
    test "returns success with analytics collected" do
      payload = %{}

      {:ok, result} = AnalyticsHandler.handle(payload, %{})

      assert result.status == "collected"
      assert is_binary(result.event_id)
      assert result.timestamp
    end

    test "includes channel metrics in response" do
      payload = %{}

      {:ok, result} = AnalyticsHandler.handle(payload, %{})

      assert Map.has_key?(result, :channel_metrics)
      assert is_integer(result.videos_analyzed)
    end
  end
end
