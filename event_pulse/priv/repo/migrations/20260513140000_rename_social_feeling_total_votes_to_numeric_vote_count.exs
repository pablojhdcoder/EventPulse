defmodule EventPulse.Repo.Migrations.RenameSocialFeelingTotalVotesToNumericVoteCount do
  use Ecto.Migration

  def change do
    rename table(:social_feeling_results), :total_votes, to: :numeric_vote_count
  end
end
