defmodule BotArmyYoutubeManager.Handlers.SummaryHandlerTest do
  use ExUnit.Case
  @moduletag :handlers

  alias BotArmyYoutubeManager.Handlers.SummaryHandler

  describe "handle/2" do
    test "returns success with summary ready" do
      payload = %{}

      {:ok, result} = SummaryHandler.handle(payload, %{})

      assert result.status == "ready_for_writing"
      assert is_binary(result.event_id)
      assert result.timestamp
    end

    test "includes summary structure" do
      payload = %{}

      {:ok, result} = SummaryHandler.handle(payload, %{})

      assert Map.has_key?(result, :summary)
      assert result.summary.period == "weekly"
      assert is_list(result.summary.videos_published)
      assert is_list(result.recommendations)
    end
  end
end
