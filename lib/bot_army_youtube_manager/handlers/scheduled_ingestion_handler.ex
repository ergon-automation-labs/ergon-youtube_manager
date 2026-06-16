defmodule BotArmyYoutubeManager.Handlers.ScheduledIngestionHandler do
  @moduledoc """
  Handles scheduled YouTube transcript ingestion from PARA inbox.

  Workflow:
  1. Reads youtube/inbox/capture.md from PARA
  2. Extracts YouTube links from each line
  3. Calls media.ingestion.youtube.transcript.get for each link
  4. Updates youtube/inbox/capture.md in PARA with remaining links
  5. Updates media_ingestion with processed links
  """

  require Logger

  alias BotArmyRuntime.NATS.Reply

  @para_read_subject "para.fs.read"
  @para_write_subject "para.fs.write"
  @media_ingest_subject "media.ingestion.youtube.transcript.get"
  @capture_path "inbox/youtube/capture.md"
  @nats_timeout 30_000

  def handle(msg) do
    with {:ok, content} <- read_capture_file(),
         {:ok, lines} <- extract_lines(content),
         {:ok, youtube_links, remaining_lines} <- separate_youtube_links(lines),
         {:ok, processed} <- process_youtube_links(youtube_links),
         :ok <- update_capture_file(remaining_lines),
         :ok <- log_completion(processed) do
      {:ok,
       %{
         "status" => "success",
         "total_links_found" => length(youtube_links),
         "processed" => length(processed),
         "remaining_lines" => length(remaining_lines),
         "processed_urls" => Enum.map(processed, & &1["url"])
       }}
    else
      {:error, reason} ->
        Logger.error("[ScheduledIngestionHandler] Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp read_capture_file do
    request_body = Jason.encode!(%{"relative_path" => @capture_path})

    case make_request(@para_read_subject, request_body) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, %{"data" => %{"content" => content}}} ->
            {:ok, content}

          {:ok, %{"data" => data}} when is_binary(data) ->
            {:ok, data}

          {:ok, %{"error" => error}} ->
            {:error, "PARA read error: #{error}"}

          {:error, _} ->
            {:error, "Failed to decode PARA response"}
        end

      {:error, reason} ->
        {:error, "PARA read failed: #{inspect(reason)}"}
    end
  end

  defp extract_lines(content) when is_binary(content) do
    lines =
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {:ok, lines}
  end

  defp extract_lines(_), do: {:error, "Invalid content"}

  defp separate_youtube_links(lines) do
    youtube_pattern = ~r{(?:https?://)?(?:www\.)?(?:youtube\.com|youtu\.be)}

    {youtube_links, remaining} =
      Enum.split_with(lines, fn line ->
        String.match?(line, youtube_pattern)
      end)

    {:ok, youtube_links, remaining}
  end

  defp process_youtube_links(links) do
    Enum.reduce_while(links, [], fn url, acc ->
      case fetch_transcript(url) do
        {:ok, data} ->
          Logger.info("[ScheduledIngestionHandler] Processed: #{url}")
          {:cont, [Map.put(data, "url", url) | acc]}

        {:error, reason} ->
          Logger.warn("[ScheduledIngestionHandler] Failed to fetch #{url}: #{inspect(reason)}")
          {:cont, acc}
      end
    end)
    |> then(&{:ok, &1})
  end

  defp fetch_transcript(url) do
    request_body = Jason.encode!(%{"youtube_url" => url})

    case make_request(@media_ingest_subject, request_body) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, %{"data" => data}} when is_map(data) ->
            {:ok, data}

          {:ok, %{"error" => error}} ->
            {:error, "Ingest error: #{error}"}

          {:error, _} ->
            {:error, "Failed to decode media response"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_capture_file(remaining_lines) do
    content = Enum.join(remaining_lines, "\n")

    request_body =
      Jason.encode!(%{"relative_path" => @capture_path, "content" => content, "mode" => "write"})

    case make_request(@para_write_subject, request_body) do
      {:ok, response} ->
        case Jason.decode(response) do
          {:ok, %{"data" => _}} ->
            Logger.info(
              "[ScheduledIngestionHandler] Updated capture.md: #{length(remaining_lines)} lines remaining"
            )

            :ok

          {:ok, %{"error" => error}} ->
            {:error, "PARA write error: #{error}"}

          {:error, _} ->
            {:error, "Failed to decode PARA write response"}
        end

      {:error, reason} ->
        {:error, "PARA write failed: #{inspect(reason)}"}
    end
  end

  defp log_completion(processed) do
    Logger.info(
      "[ScheduledIngestionHandler] Completed: #{length(processed)} transcripts processed"
    )

    :ok
  end

  defp make_request(subject, body) do
    with {:ok, conn} <- GenServer.call(BotArmyRuntime.NATS.Connection, :get_connection, 5000) do
      case Gnat.request(conn, subject, body, receive_timeout: @nats_timeout) do
        {:ok, msg} -> {:ok, msg.body}
        {:error, reason} -> {:error, reason}
      end
    end
  rescue
    e ->
      {:error, "Request failed: #{inspect(e)}"}
  end
end
