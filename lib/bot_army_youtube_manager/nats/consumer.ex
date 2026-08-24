defmodule BotArmyYoutubeManager.NATS.Consumer do
  @moduledoc """
  NATS message consumer for youtube_manager.

  Subscribes to NATS subjects and routes messages to handlers.
  Uses standardized Reply format for request/reply patterns.

  All request/reply handlers should return responses using Reply helpers:
  - BotArmyLibraryRuntime.NATS.Reply.ok(data) for success
  - BotArmyLibraryRuntime.NATS.Reply.error(message, code) for errors
  """

  use GenServer
  require Logger

  @reconnect_delay_ms 5000
  @registry_heartbeat_ms 20_000
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
      subject: "youtube.learning.validate",
      type: :request_reply,
      description: "Validate anomaly detection predictions"
    },
    %{
      subject: "youtube.learning.propose",
      type: :request_reply,
      description: "Generate optimization proposals from validation results"
    },
    %{
      subject: "youtube.scheduled.ingest",
      type: :request_reply,
      description: "Scheduled ingestion: read capture.md, process YouTube links, update PARA"
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
      opts: opts,
      # LeaderElection announces the real role shortly after startup; defaulting
      # to standby means a not-yet-elected node never answers business traffic.
      role: :standby
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case GenServer.call(BotArmyLibraryRuntime.NATS.Connection, :get_connection, 5000) do
      {:ok, conn} ->
        BotArmyLibraryRuntime.NATS.Connection.subscribe_to_status()
        state = %{state | conn: conn}

        if state.role == :primary do
          subscribe_business_subjects(state)
        else
          Logger.info("YouTube Manager consumer standby — not subscribing to business subjects")
          {:noreply, register_with_role(%{state | subscriptions: []})}
        end

      {:error, _reason} ->
        Logger.warning("NATS connection not ready, will retry")
        Process.send_after(self(), :connect_retry, @reconnect_delay_ms)
        {:noreply, state}
    end
  end

  @doc """
  Called by `BotArmyLibraryRuntime.LeaderElection`'s `on_role_change` callback.
  """
  def leader_role_changed(role) when role in [:primary, :standby] do
    GenServer.cast(__MODULE__, {:leader_role_changed, role})
  end

  @impl true
  def handle_cast({:leader_role_changed, :primary}, %{conn: nil} = state) do
    Logger.warning(
      "YouTube Manager consumer designated PRIMARY, but NATS not connected yet — will subscribe once connected"
    )

    {:noreply, %{state | role: :primary}}
  end

  def handle_cast({:leader_role_changed, :primary}, %{subscriptions: []} = state) do
    Logger.warning("YouTube Manager consumer becoming PRIMARY — subscribing to business subjects")
    subscribe_business_subjects(%{state | role: :primary})
  end

  def handle_cast({:leader_role_changed, :primary}, state) do
    {:noreply, %{state | role: :primary}}
  end

  def handle_cast({:leader_role_changed, :standby}, state) do
    Logger.warning(
      "YouTube Manager consumer becoming STANDBY — unsubscribing from business subjects"
    )

    if state.conn do
      Enum.each(state.subscriptions, &Gnat.unsub(state.conn, &1))
    end

    {:noreply, register_with_role(%{state | role: :standby, subscriptions: []})}
  end

  defp subscribe_business_subjects(state) do
    Logger.info("Connected to NATS, subscribing to topics")

    subscriptions =
      [
        "youtube.analytics.fetch",
        "youtube.summary.generate",
        "youtube.learning.validate",
        "youtube.learning.propose",
        "youtube.scheduled.ingest"
      ]
      |> Enum.map(fn subject ->
        case Gnat.sub(state.conn, self(), subject) do
          {:ok, sub} ->
            Logger.info("Subscribed to #{subject}")
            sub

          {:error, reason} ->
            Logger.error("CRITICAL: Failed to subscribe to #{subject}: #{inspect(reason)}")
            nil
        end
      end)
      |> Enum.filter(&(not is_nil(&1)))

    active_count = length(subscriptions)
    expected_count = 5

    case active_count do
      ^expected_count ->
        Logger.info("[Consumer] All 4 subscriptions active")

      _ ->
        Logger.error(
          "[Consumer] WARNING: Only #{active_count}/#{expected_count} subscriptions active!"
        )
    end

    {:noreply, register_with_role(%{state | subscriptions: subscriptions})}
  end

  # Registers with the fleet Registry, reflecting the current role in
  # deployment_status so a standby node is visible but clearly not serving.
  defp register_with_role(state) do
    deployment_status =
      if state.role == :primary do
        Application.get_env(:bot_army_youtube_manager, :deployment_status, "deployed")
      else
        "standby"
      end

    BotArmyLibraryRuntime.Registry.register(
      "youtube_manager",
      @subjects,
      @version,
      deployment_status
    )

    Process.send_after(self(), :registry_heartbeat, @registry_heartbeat_ms)
    state
  end

  @impl true
  def handle_info(:connect_retry, state) do
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    BotArmyLibraryRuntime.Tracing.with_consumer_span(msg.topic, Map.get(msg, :headers), fn ->
      Logger.debug("Received NATS message on subject: #{msg.topic}")

      # Handle request/reply patterns
      if msg.reply_to do
        case msg.topic do
          "youtube.analytics.fetch" ->
            handle_analytics_fetch(msg, state)

          "youtube.summary.generate" ->
            handle_summary_generate(msg, state)

          "youtube.learning.validate" ->
            handle_learning_validate(msg, state)

          "youtube.learning.propose" ->
            handle_learning_propose(msg, state)

          "youtube.scheduled.ingest" ->
            handle_scheduled_ingest(msg, state)

          _ ->
            Logger.debug("Unknown request/reply subject: #{msg.topic}")
        end
      else
        # Handle pub/sub messages
        case BotArmyLibraryCore.NATS.Decoder.decode(msg.body) do
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
  def handle_info(:registry_heartbeat, state) do
    {:noreply, register_with_role(state)}
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
    Logger.info("[AnalyticsFetch] Received request, reply_to=#{msg.reply_to}")

    try do
      Logger.debug("[AnalyticsFetch] Decoding payload")

      case BotArmyLibraryCore.NATS.Decoder.decode(msg.body) do
        {:ok, payload} ->
          Logger.debug("[AnalyticsFetch] Payload decoded successfully")

          case BotArmyYoutubeManager.Handlers.AnalyticsHandler.handle(payload, %{}) do
            {:ok, result} ->
              Logger.info("[AnalyticsFetch] Handler succeeded, preparing response")
              response = BotArmyLibraryRuntime.NATS.Reply.ok(result)

              if state.conn do
                Logger.info("[AnalyticsFetch] Publishing response")
                Gnat.pub(state.conn, msg.reply_to, response)
              else
                Logger.error("[AnalyticsFetch] No NATS connection available!")
              end

            {:error, reason} ->
              Logger.error("[AnalyticsFetch] Handler failed: #{inspect(reason)}")

              response =
                BotArmyLibraryRuntime.NATS.Reply.error(inspect(reason), :analytics_failed)

              if state.conn do
                Gnat.pub(state.conn, msg.reply_to, response)
              else
                Logger.error("[AnalyticsFetch] No NATS connection available!")
              end
          end

        {:error, reason} ->
          Logger.error("[AnalyticsFetch] Decode failed: #{inspect(reason)}")
          response = BotArmyLibraryRuntime.NATS.Reply.error(inspect(reason), :decode_failed)

          if state.conn do
            Gnat.pub(state.conn, msg.reply_to, response)
          else
            Logger.error("[AnalyticsFetch] No NATS connection available!")
          end
      end
    rescue
      e ->
        Logger.error("[AnalyticsFetch] Handler crashed: #{inspect(e)}")

        response =
          BotArmyLibraryRuntime.NATS.Reply.error(
            "Handler exception: #{inspect(e)}",
            :handler_crash
          )

        if state.conn do
          Gnat.pub(state.conn, msg.reply_to, response)
        else
          Logger.error("[AnalyticsFetch] No NATS connection available!")
        end
    end
  end

  defp handle_summary_generate(msg, state) do
    case BotArmyLibraryCore.NATS.Decoder.decode(msg.body) do
      {:ok, payload} ->
        case BotArmyYoutubeManager.Handlers.SummaryHandler.handle(payload, %{}) do
          {:ok, result} ->
            publish_summary_to_para(result, state)
            publish_summary_to_discord(result)
            response = BotArmyLibraryRuntime.NATS.Reply.ok(result)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end

          {:error, reason} ->
            response = BotArmyLibraryRuntime.NATS.Reply.error(reason, :summary_failed)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end
        end

      {:error, reason} ->
        response = BotArmyLibraryRuntime.NATS.Reply.error(inspect(reason), :decode_failed)

        if state.conn do
          Gnat.pub(state.conn, msg.reply_to, response)
        end
    end
  end

  defp handle_learning_validate(msg, state) do
    case BotArmyLibraryCore.NATS.Decoder.decode(msg.body) do
      {:ok, payload} ->
        case BotArmyYoutubeManager.Handlers.ValidationHandler.handle(payload, %{}) do
          {:ok, result} ->
            response = BotArmyLibraryRuntime.NATS.Reply.ok(result)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end

          {:error, reason} ->
            response = BotArmyLibraryRuntime.NATS.Reply.error(reason, :validation_failed)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end
        end

      {:error, reason} ->
        response = BotArmyLibraryRuntime.NATS.Reply.error(inspect(reason), :decode_failed)

        if state.conn do
          Gnat.pub(state.conn, msg.reply_to, response)
        end
    end
  end

  defp handle_learning_propose(msg, state) do
    case BotArmyLibraryCore.NATS.Decoder.decode(msg.body) do
      {:ok, payload} ->
        case BotArmyYoutubeManager.Handlers.ProposerHandler.handle(payload, %{}) do
          {:ok, result} ->
            response = BotArmyLibraryRuntime.NATS.Reply.ok(result)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end

          {:error, reason} ->
            response = BotArmyLibraryRuntime.NATS.Reply.error(reason, :proposal_failed)

            if state.conn do
              Gnat.pub(state.conn, msg.reply_to, response)
            end
        end

      {:error, reason} ->
        response = BotArmyLibraryRuntime.NATS.Reply.error(inspect(reason), :decode_failed)

        if state.conn do
          Gnat.pub(state.conn, msg.reply_to, response)
        end
    end
  end

  defp publish_summary_to_para(result, _state) do
    case result do
      %{para_path: path, markdown: markdown} ->
        case BotArmyYoutubeManager.Learning.ParaWriter.write_to_para(path, markdown) do
          {:ok, path} ->
            Logger.info("Published summary to PARA", path: path)

          {:error, reason} ->
            Logger.error("Failed to write summary to PARA", path: path, reason: inspect(reason))
        end

      _ ->
        Logger.warning("Summary missing required fields for PARA write", result: inspect(result))
    end
  end

  defp publish_summary_to_discord(result) do
    BotArmyYoutubeManager.Discord.Publisher.publish_summary_to_discord(result)
  end

  defp handle_scheduled_ingest(msg, state) do
    Logger.info("[ScheduledIngest] Received scheduled ingestion request")

    try do
      case BotArmyYoutubeManager.Handlers.ScheduledIngestionHandler.handle(msg) do
        {:ok, result} ->
          Logger.info("[ScheduledIngest] Handler succeeded")
          response = BotArmyLibraryRuntime.NATS.Reply.ok(result)

          if state.conn do
            Gnat.pub(state.conn, msg.reply_to, response)
          else
            Logger.error("[ScheduledIngest] No NATS connection available!")
          end

        {:error, reason} ->
          Logger.error("[ScheduledIngest] Handler failed: #{inspect(reason)}")
          response = BotArmyLibraryRuntime.NATS.Reply.error(inspect(reason), :ingest_failed)

          if state.conn do
            Gnat.pub(state.conn, msg.reply_to, response)
          else
            Logger.error("[ScheduledIngest] No NATS connection available!")
          end
      end
    rescue
      e ->
        Logger.error("[ScheduledIngest] Handler crashed: #{inspect(e)}")

        response =
          BotArmyLibraryRuntime.NATS.Reply.error(
            "Handler exception: #{inspect(e)}",
            :handler_crash
          )

        if state.conn do
          Gnat.pub(state.conn, msg.reply_to, response)
        else
          Logger.error("[ScheduledIngest] No NATS connection available!")
        end
    end
  end
end
