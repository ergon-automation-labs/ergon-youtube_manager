defmodule BotArmyYoutubeManager.Schemas.LearningOptimizationProposal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "learning_optimization_proposals" do
    field(:category, :string)
    field(:type, :string)
    field(:current_value, :float)
    field(:proposed_value, :float)
    field(:reason, :string)
    field(:status, :string)

    field(:proposed_at, :utc_datetime)
    field(:reviewed_at, :utc_datetime)

    timestamps()
  end

  def changeset(proposal, attrs) do
    proposal
    |> cast(attrs, [
      :category,
      :type,
      :current_value,
      :proposed_value,
      :reason,
      :status,
      :proposed_at,
      :reviewed_at
    ])
    |> validate_required([
      :category,
      :type,
      :current_value,
      :proposed_value,
      :reason,
      :proposed_at
    ])
    |> validate_inclusion(:status, ["pending", "approved", "rejected", "implemented"])
  end
end
