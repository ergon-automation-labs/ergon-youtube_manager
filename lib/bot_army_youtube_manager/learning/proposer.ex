defmodule BotArmyYoutubeManager.Learning.Proposer do
  @moduledoc """
  Analyzes validation results and proposes anomaly detection improvements.

  Calculates accuracy metrics per anomaly type and severity, identifies patterns,
  and generates optimization proposals for threshold adjustments.
  """

  require Logger
  import Ecto.Query

  alias BotArmyYoutubeManager.{
    Repo,
    Schemas.LearningOutcome,
    Schemas.LearningOptimizationProposal
  }

  @min_sample_size 10

  def propose_optimizations do
    Logger.info("Analyzing validation results for optimization proposals")

    accuracy_stats = calculate_accuracy_stats()
    Logger.info("Calculated accuracy stats: #{inspect(accuracy_stats)}")

    proposals = generate_proposals(accuracy_stats)
    Logger.info("Generated #{length(proposals)} optimization proposals")

    results =
      Enum.map(proposals, fn proposal ->
        save_proposal(proposal)
      end)

    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))

    Logger.info("Proposals saved: #{length(successes)} successful, #{length(failures)} failed")

    {:ok, %{proposals_created: length(successes), failed: length(failures)}}
  end

  defp calculate_accuracy_stats do
    validated_outcomes = fetch_validated_outcomes()

    validated_outcomes
    |> Enum.group_by(fn outcome ->
      {parse_anomaly_type(outcome.decision), parse_severity(outcome.decision)}
    end)
    |> Enum.map(fn {{anomaly_type, severity}, outcomes} ->
      total = length(outcomes)
      correct = Enum.count(outcomes, & &1.was_correct)
      accuracy = correct / total

      %{
        anomaly_type: anomaly_type,
        severity: severity,
        total: total,
        correct: correct,
        incorrect: total - correct,
        accuracy: accuracy,
        outcomes: outcomes
      }
    end)
    |> Enum.filter(fn stat -> stat.total >= @min_sample_size end)
  end

  defp fetch_validated_outcomes do
    from(lo in LearningOutcome,
      where: not is_nil(lo.was_correct),
      order_by: [desc: lo.recorded_at]
    )
    |> Repo.all()
  end

  defp generate_proposals(accuracy_stats) do
    accuracy_stats
    |> Enum.flat_map(fn stat ->
      generate_proposals_for_stat(stat)
    end)
  end

  defp generate_proposals_for_stat(stat) do
    proposals = []

    # Proposal 1: High false positive rate
    proposals = add_false_positive_proposal(proposals, stat)

    # Proposal 2: Low overall accuracy
    proposals = add_low_accuracy_proposal(proposals, stat)

    # Proposal 3: Sensitivity adjustment
    proposals = add_sensitivity_proposal(proposals, stat)

    proposals
  end

  defp add_false_positive_proposal(proposals, stat) do
    false_positive_rate = stat.incorrect / stat.total

    if false_positive_rate > 0.4 do
      # Too many false positives - suggest stricter thresholds
      [
        %{
          category: stat.anomaly_type,
          type: "threshold_adjustment",
          current_value: severity_to_z_score(stat.severity),
          proposed_value: severity_to_z_score(stat.severity) - 0.2,
          reason:
            "High false positive rate (#{(false_positive_rate * 100) |> Float.round(1)}%) detected for #{stat.anomaly_type} at #{stat.severity} severity. Recommend stricter threshold.",
          proposed_at: DateTime.utc_now()
        }
        | proposals
      ]
    else
      proposals
    end
  end

  defp add_low_accuracy_proposal(proposals, stat) do
    if stat.accuracy < 0.6 do
      # Low accuracy overall - suggest major adjustment
      [
        %{
          category: stat.anomaly_type,
          type: "accuracy_review",
          current_value: stat.accuracy,
          proposed_value: 0.75,
          reason:
            "Low accuracy (#{(stat.accuracy * 100) |> Float.round(1)}%) for #{stat.anomaly_type} at #{stat.severity} severity. Consider disabling or redesigning this detector.",
          proposed_at: DateTime.utc_now()
        }
        | proposals
      ]
    else
      proposals
    end
  end

  defp add_sensitivity_proposal(proposals, stat) do
    correct_rate = stat.correct / stat.total

    if stat.severity == "medium" and correct_rate > 0.85 do
      # Medium severity working well - could relax to catch more
      [
        %{
          category: stat.anomaly_type,
          type: "sensitivity_increase",
          current_value: severity_to_z_score("medium"),
          proposed_value: severity_to_z_score("medium") - 0.1,
          reason:
            "High accuracy (#{(correct_rate * 100) |> Float.round(1)}%) at medium severity. Could lower threshold to catch more cases.",
          proposed_at: DateTime.utc_now()
        }
        | proposals
      ]
    else
      proposals
    end
  end

  defp severity_to_z_score("high"), do: -2.0
  defp severity_to_z_score("medium"), do: -1.5
  defp severity_to_z_score(_), do: -1.0

  defp parse_anomaly_type(decision_string) do
    case String.split(decision_string, ":") do
      [anomaly_type | _] -> anomaly_type
      _ -> "unknown"
    end
  end

  defp parse_severity(decision_string) do
    case String.split(decision_string, ":") do
      [_type, severity | _] -> severity
      _ -> "unknown"
    end
  end

  defp save_proposal(proposal_data) do
    attrs = Map.put(proposal_data, :status, "pending")

    case Repo.insert(
           LearningOptimizationProposal.changeset(%LearningOptimizationProposal{}, attrs)
         ) do
      {:ok, proposal} ->
        Logger.debug("Saved optimization proposal: #{proposal.category}/#{proposal.type}")

        {:ok, proposal}

      {:error, reason} ->
        Logger.warning(
          "Failed to save proposal for #{proposal_data.category}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
