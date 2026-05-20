defmodule BotArmyYoutubeManager.Discord.Publisher do
  @moduledoc """
  Publishes YouTube analytics summaries and anomalies to Discord.
  Uses surface_discord for messaging.
  """

  require Logger

  def publish_summary_to_discord(summary) do
    case summary do
      %{
        "para_path" => _path,
        "markdown" => markdown,
        "summary" => %{
          "period" => period,
          "total_views" => views,
          "total_watch_time" => watch_time,
          "trends" => trends
        }
      } ->
        message = build_summary_embed(period, views, watch_time, trends, markdown)
        publish_to_discord(message)

      _ ->
        Logger.warn("Summary missing required fields for Discord")
        :ok
    end
  end

  def publish_anomalies_to_discord(anomalies) when is_list(anomalies) and length(anomalies) > 0 do
    message = build_anomaly_embeds(anomalies)
    publish_to_discord(message)
  end

  def publish_anomalies_to_discord(_), do: :ok

  defp build_summary_embed(period, views, watch_time, trends, markdown) do
    title = "📊 YouTube Analytics Summary: #{period}"

    description =
      """
      **Total Views:** #{format_number(views)}
      **Total Watch Time:** #{format_number(watch_time)} min
      **Trends:** #{trends}
      """

    %{
      "embeds" => [
        %{
          "title" => title,
          "description" => description,
          "color" => 5_814_783,
          "footer" => %{
            "text" => "YouTube Manager Bot"
          },
          "fields" => [
            %{
              "name" => "Full Summary",
              "value" => "See PARA: projects/Bot Army/YouTube Analytics",
              "inline" => false
            }
          ]
        }
      ]
    }
  end

  defp build_anomaly_embeds(anomalies) do
    embeds =
      Enum.map(anomalies, fn {type, reason, severity} ->
        color = color_for_severity(severity)

        %{
          "title" => "⚠️ Anomaly Detected: #{type}",
          "description" => reason,
          "color" => color,
          "fields" => [
            %{
              "name" => "Severity",
              "value" => String.upcase(to_string(severity)),
              "inline" => true
            }
          ]
        }
      end)

    %{"embeds" => embeds}
  end

  defp publish_to_discord(message) do
    subject = "surface.discord.send"
    encoded = BotArmyCore.NATS.Encoder.encode(message)

    case BotArmyCore.NATS.publish(subject, encoded) do
      {:ok, _} ->
        Logger.info("Published message to Discord", subject: subject)
        :ok

      {:error, reason} ->
        Logger.warn("Failed to publish to Discord: #{reason}")
        {:error, reason}
    end
  end

  defp color_for_severity(severity) do
    case severity do
      :high -> 15_158_332
      :medium -> 16_776_960
      _ -> 9_807_270
    end
  end

  defp format_number(n) when is_number(n) do
    n |> round() |> Integer.to_string()
  end

  defp format_number(n), do: to_string(n)
end
