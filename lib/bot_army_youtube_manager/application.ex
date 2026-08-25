defmodule BotArmyYoutubeManager.Application do
  @moduledoc """
  YouTube Manager Bot application supervisor.

  Follows bot army pattern with environment-aware startup:
  - Repo not started in :test (tests inject mocks)
  - PulsePublisher sends `system.health` liveness every 30s and rich `bot.<service>.pulse` every 30 minutes
  - Workers not started in :test (gated by @env)

  Observability: see `PulsePublisher` — fleet UIs keyed on Synapse hydration should use `system.health` freshness (90s), not pulse interval alone.
  """

  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
    # Note: BotArmyLibraryRuntime.Telemetry and BotArmyLibraryRuntime.NATS.Connection are started
    # by bot_army_runtime automatically — do not add them here.

    children =
      []
      |> maybe_add_repo()
      |> maybe_add_pulse_publisher()
      |> maybe_add_workers()

    opts = [strategy: :one_for_one, name: BotArmyYoutubeManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add_repo(children) do
    if @env == :test do
      children
    else
      [{BotArmyYoutubeManager.Repo, []} | children]
    end
  end

  defp maybe_add_pulse_publisher(children) do
    if @env == :test do
      children
    else
      [{BotArmyYoutubeManager.PulsePublisher, []} | children]
    end
  end

  defp maybe_add_workers(children) do
    if @env == :test do
      children
    else
      # Bot-specific workers and pollers go here (GenServers that do async work)
      # Examples: Scheduler, Poller, Watcher
      # Pattern: gated with if @env == :test to prevent long-running processes in test
      [
        # Leader/standby election for dual-node (air + mini) deployment — must
        # start before the consumer so its first on_role_change call lands
        # while the consumer is still connecting (not yet subscribed either way).
        {BotArmyLibraryRuntime.LeaderElection,
         service: "youtube_manager",
         node_name: System.get_env("NODE_NAME", "unknown"),
         default_role:
           BotArmyLibraryRuntime.LeaderElection.role_from_env("YOUTUBE_MANAGER_NODE_ROLE"),
         on_role_change: {BotArmyYoutubeManager.NATS.Consumer, :leader_role_changed, []}},
        {BotArmyYoutubeManager.NATS.Consumer, []}
        | children
      ]
    end
  end
end
