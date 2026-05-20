defmodule BotArmyYoutubeManager.Repo.Migrations.CreateLearningTables do
  use Ecto.Migration

  def change do
    # Learning outcomes: track decisions and their actual results
    create table(:learning_outcomes, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:item_id, :string, null: false)
      add(:category, :string, null: false)
      add(:decision, :string, null: false)
      add(:actual_result, :string, null: false)
      add(:was_correct, :boolean, null: false)
      add(:recorded_at, :utc_datetime, null: false)
      add(:inserted_at, :utc_datetime, null: false, default: fragment("NOW()"))
    end

    create(index(:learning_outcomes, [:category, :item_id]))
    create(index(:learning_outcomes, [:recorded_at, :category]))

    # Learning prompt variants: track different prompt versions and their performance
    create table(:learning_prompt_variants, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:task_type, :string, null: false)
      add(:prompt_hash, :string, null: false)
      add(:prompt_text, :text, null: false)
      add(:total_score, :float, null: false)
      add(:uses, :integer, null: false)
      add(:last_updated_at, :utc_datetime, null: false)
      add(:created_at, :utc_datetime, null: false, default: fragment("NOW()"))
    end

    create(
      unique_index(:learning_prompt_variants, [:task_type, :prompt_hash],
        name: :learning_prompt_variants_task_type_prompt_hash_index
      )
    )

    create(index(:learning_prompt_variants, [:task_type]))

    # Learning optimization proposals: track proposed improvements
    create table(:learning_optimization_proposals, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:category, :string, null: false)
      add(:type, :string, null: false)
      add(:current_value, :float, null: false)
      add(:proposed_value, :float, null: false)
      add(:reason, :text, null: false)
      add(:status, :string, null: false, default: "pending")
      add(:proposed_at, :utc_datetime, null: false)
      add(:reviewed_at, :utc_datetime)
      add(:created_at, :utc_datetime, null: false, default: fragment("NOW()"))
    end

    create(index(:learning_optimization_proposals, [:category, :status]))
    create(index(:learning_optimization_proposals, [:status]))
  end
end
