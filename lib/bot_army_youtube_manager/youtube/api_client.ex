defmodule BotArmyYoutubeManager.Youtube.ApiClient do
  @moduledoc """
  YouTube Analytics API client for fetching channel metrics and video performance data.

  Uses OAuth 2.0 authentication (server-side web app flow). Requires YOUTUBE_OAUTH_ACCESS_TOKEN
  in environment, which is obtained via initial user authorization in Youtube.OAuth module.
  """

  require Logger

  @analytics_endpoint "https://youtubeanalytics.googleapis.com/v2/reports"

  @spec fetch_video_metrics(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def fetch_video_metrics(video_id, opts \\ %{}) do
    case get_access_token() do
      {:ok, access_token} ->
        fetch_metrics(video_id, access_token, opts)

      {:error, reason} ->
        {:error, "Failed to authenticate: #{reason}"}
    end
  end

  @spec fetch_channel_metrics(map()) :: {:ok, map()} | {:error, String.t()}
  def fetch_channel_metrics(opts \\ %{}) do
    case get_access_token() do
      {:ok, access_token} ->
        fetch_channel_data(access_token, opts)

      {:error, reason} ->
        {:error, "Failed to authenticate: #{reason}"}
    end
  end

  defp get_access_token do
    if Mix.env() == :test do
      {:ok, "test_access_token"}
    else
      case BotArmyYoutubeManager.Youtube.OAuth.get_valid_access_token() do
        {:ok, token} -> {:ok, token}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp fetch_metrics(video_id, access_token, _opts) do
    Logger.info("Fetching metrics for video: #{video_id}")

    if Mix.env() == :test do
      {:ok,
       %{
         video_id: video_id,
         views: 0,
         watch_time_minutes: 0,
         average_view_duration_seconds: 0.0,
         ctr: 0.0,
         engagement: %{},
         traffic_sources: %{}
       }}
    else
      params = %{
        "ids" => "channel==MINE",
        "metrics" => "views,estimatedMinutesWatched,averageViewDuration,ctr",
        "filters" => "video==#{video_id}",
        "startDate" => Date.add(Date.utc_today(), -7) |> Date.to_iso8601(),
        "endDate" => Date.utc_today() |> Date.to_iso8601()
      }

      case make_request(access_token, params) do
        {:ok, data} ->
          parse_video_metrics(video_id, data)

        {:error, reason} ->
          Logger.error("Failed to fetch video metrics: #{reason}")
          {:error, reason}
      end
    end
  end

  defp fetch_channel_data(access_token, _opts) do
    Logger.info("Fetching channel analytics data")

    if Mix.env() == :test do
      {:ok,
       %{
         channel_id: nil,
         total_views: 0,
         total_watch_time: 0,
         videos: [],
         subscriber_change: 0
       }}
    else
      params = %{
        "ids" => "channel==MINE",
        "metrics" => "views,estimatedMinutesWatched,subscriberGain",
        "startDate" => Date.add(Date.utc_today(), -7) |> Date.to_iso8601(),
        "endDate" => Date.utc_today() |> Date.to_iso8601(),
        "dimensions" => "video"
      }

      case make_request(access_token, params) do
        {:ok, data} ->
          parse_channel_data(data)

        {:error, reason} ->
          Logger.error("Failed to fetch channel data: #{reason}")
          {:error, reason}
      end
    end
  end

  defp make_request(access_token, params) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/json"}
    ]

    case Req.get(@analytics_endpoint, headers: headers, params: params) do
      {:ok, response} ->
        data = response.body

        if is_map(data) && Map.has_key?(data, "error") do
          {:error, Map.get(data, "error") |> inspect()}
        else
          {:ok, data}
        end

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp parse_video_metrics(video_id, data) do
    rows = Map.get(data, "rows", [])

    if Enum.empty?(rows) do
      {:ok,
       %{
         video_id: video_id,
         views: 0,
         watch_time_minutes: 0,
         average_view_duration_seconds: 0.0,
         ctr: 0.0,
         engagement: %{},
         traffic_sources: %{}
       }}
    else
      [row | _] = rows

      {:ok,
       %{
         video_id: video_id,
         views: Enum.at(row, 0, 0),
         watch_time_minutes: Enum.at(row, 1, 0),
         average_view_duration_seconds: Enum.at(row, 2, 0.0),
         ctr: Enum.at(row, 3, 0.0),
         engagement: %{},
         traffic_sources: %{}
       }}
    end
  end

  defp parse_channel_data(data) do
    rows = Map.get(data, "rows", [])

    videos =
      Enum.map(rows, fn row ->
        %{
          video_id: Enum.at(row, 0),
          views: Enum.at(row, 1, 0),
          watch_time_minutes: Enum.at(row, 2, 0)
        }
      end)

    {:ok,
     %{
       channel_id: nil,
       total_views: Enum.sum(Enum.map(rows, &Enum.at(&1, 1, 0))),
       total_watch_time: Enum.sum(Enum.map(rows, &Enum.at(&1, 2, 0))),
       videos: videos,
       subscriber_change: 0
     }}
  end
end
