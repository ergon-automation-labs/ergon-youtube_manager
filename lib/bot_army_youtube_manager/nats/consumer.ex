defmodule BotArmyYoutubeManager.NATS.Consumer do
  @moduledoc """
  NATS message consumer for youtube_manager.

  Subscribes to NATS subjects and routes messages to handlers.
  Uses standardized Reply format for request/reply patterns.

  All request/reply handlers should return responses using Reply helpers:
  - BotArmyRuntime.NATS.Reply.ok(data) for success
  - BotArmyRuntime.NATS.Reply.error(message, code) for errors
  """

  use GenServer
  require Logger

  @reconnect_delay_ms 5000
  @version Mix.Project.config()[:version]

  # Register subjects with their metadata for runtime discovery
  @subjects [
    %{
      subject: "youtube.analytics.fetch",
      type: :request_reply,
      description: "Fetch YouTube analytics data"
    },
    %{
      subject: "youtube.summary.generate",
      type: :request_reply,
      description: "Generate weekly summary"
    },
    %{
      subject: "youtube.analytics.updated",
      type: :publish,
      description: "Published when analytics are updated"
    },
    %{
      subject: "youtube.insights.generated",
      type: :publish,
      description: "Published when insights are generated"
    },
    %{
      subject: "youtube.alert.performance",
      type: :publish,
      description: "Published for performance anomalies"
    }
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting NATS consumer")

    state = %{
      subscriptions: [],
      conn: nil,
      opts: opts
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case GenServer.call(BotArmyRuntime.NATS.Connection, :get_connection, 5000) do
      {:ok, conn} ->
        BotArmyRuntime.NATS.Connection.subscribe_to_status()
        Logger.info("Connected to NATS, subscribing to topics")

        subscriptions =
          [
            "youtube.analytics.fetch",
            "youtube.summary.generate"
          ]
          |> Enum.map(fn subject ->
            case Gnat.sub(conn, self(), subject) do
              {:ok, sub} ->
                Logger.info("Subscribed to #{subject}")
                sub

              {:error, reason} ->
                Logger.error("Failed to subscribe to #{subject}: #{inspect(reason)}")
                nil
            end
          end)
          |> Enum.filter(&(not is_nil(&1)))

        # Register subjects for runtime discovery
        BotArmyRuntime.Registry.register("youtube_manager", @subjects, @version)

        {:noreply, %{state | subscriptions: subscriptions, conn: conn}}

      {:error, _reason} ->
        Logger.warning("NATS connection not ready, will retry")
        Process.send_after(self(), :connect_retry, @reconnect_delay_ms)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:connect_retry, state) do
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    BotArmyRuntime.Tracing.with_consumer_span(msg.topic, Map.get(msg, :headers), fn ->
      Logger.debug("Received NATS message on subject: #{msg.topic}")

      # Handle request/reply patterns
      if msg.reply_to do
        case msg.topic do
          "youtube.analytics.fetch" ->
            handle_analytics_fetch(msg, state)

          "youtube.summary.generate" ->
            handle_summary_generate(msg, state)

          _ ->
            Logger.debug("Unknown request/reply subject: #{msg.topic}")
        end
      else
        # Handle pub/sub messages
        case BotArmyCore.NATS.Decoder.decode(msg.body) do
          {:ok, decoded_message} ->
            route_message(decoded_message, msg.topic)

          {:error, reason} ->
            Logger.warning("Failed to decode message from #{msg.topic}: #{inspect(reason)}")
        end
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:nats, :disconnected}, state) do
    Logger.warning("Disconnected from NATS, will reconnect")
    Process.send_after(self(), :connect_retry, @reconnect_delay_ms)
    {:noreply, %{state | subscriptions: [], conn: nil}}
  end

  @impl true
  def handle_info({:nats, :connected}, state) do
    Logger.info("Reconnected to NATS, re-subscribing")
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  # Message routing
  defp route_message(_message, topic) do
    # Route decoded messages to appropriate handlers
    Logger.debug("Routing message from #{topic}")
  end

  # Request/reply handlers
  defp handle_analytics_fetch(msg, state) do
    case BotArmyCore.NATS.Decoder.decode(msg.body) do
      {:ok, payload} ->
        case BotArmyYoutubeManager.Handlers.AnalyticsHandler.handle(payload, %{}) do
          {:ok, result} ->
            response = BotArmyRuntime.NATS.Reply.ok(result)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end

          {:error, reason} ->
            response = BotArmyRuntime.NATS.Reply.error(reason, :analytics_failed)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end
        end

      {:error, reason} ->
        response = BotArmyRuntime.NATS.Reply.error(inspect(reason), :decode_failed)

        if state.conn do
          Gnat.pub(state.conn, msg.reply_to, response)
        end
    end
  end

  defp handle_summary_generate(msg, state) do
    case BotArmyCore.NATS.Decoder.decode(msg.body) do
      {:ok, payload} ->
        case BotArmyYoutubeManager.Handlers.SummaryHandler.handle(payload, %{}) do
          {:ok, result} ->
            publish_summary_to_para(result, state)
            publish_summary_to_discord(result)
            response = BotArmyRuntime.NATS.Reply.ok(result)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end

          {:error, reason} ->
            response = BotArmyRuntime.NATS.Reply.error(reason, :summary_failed)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end
        end

      {:error, reason} ->
        response = BotArmyRuntime.NATS.Reply.error(inspect(reason), :decode_failed)

        if state.conn do
          Gnat.pub(state.conn, msg.reply_to, response)
        end
    end
  end

  defp publish_summary_to_para(result, state) do
    case result do
      %{"para_path" => path, "markdown" => markdown} ->
        payload = %{
          "path" => path,
          "content" => markdown
        }

        encoded = BotArmyCore.NATS.Encoder.encode(payload)

        if state.conn do
          Gnat.pub(state.conn, "para.fs.write", encoded)
          Logger.info("Published summary to PARA", path: path)
        end

      _ ->
        Logger.warn("Summary missing required fields for PARA write")
    end
  end

  defp publish_summary_to_discord(result) do
    BotArmyYoutubeManager.Discord.Publisher.publish_summary_to_discord(result)
  end
end
