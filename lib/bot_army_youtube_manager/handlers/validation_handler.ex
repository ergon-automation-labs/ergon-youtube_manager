defmodule BotArmyYoutubeManager.Handlers.ValidationHandler do
  @moduledoc """
  Handles youtube.learning.validate requests to check if anomaly predictions came true.
  """

  require Logger
  alias BotArmyYoutubeManager.Learning.Validator

  def handle(_payload, _opts) do
    Logger.info("Processing learning validation request")

    case Validator.validate_pending_decisions() do
      {:ok, result} ->
        {:ok,
         Map.merge(result, %{
           event_id: UUID.uuid4(),
           timestamp: DateTime.utc_now(),
           status: "validation_complete"
         })}

      {:error, reason} ->
        {:error, "Validation failed: #{reason}"}
    end
  end
end
