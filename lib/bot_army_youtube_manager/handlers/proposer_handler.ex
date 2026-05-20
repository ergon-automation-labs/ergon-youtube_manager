defmodule BotArmyYoutubeManager.Handlers.ProposerHandler do
  @moduledoc """
  Handles youtube.learning.propose requests to generate optimization proposals.
  """

  require Logger
  alias BotArmyYoutubeManager.Learning.Proposer

  def handle(_payload, _opts) do
    Logger.info("Processing learning proposal request")

    case Proposer.propose_optimizations() do
      {:ok, result} ->
        {:ok,
         Map.merge(result, %{
           event_id: UUID.uuid4(),
           timestamp: DateTime.utc_now(),
           status: "proposals_generated"
         })}

      {:error, reason} ->
        {:error, "Proposal generation failed: #{reason}"}
    end
  end
end
