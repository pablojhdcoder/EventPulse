defmodule EventPulse.Repo.Migrations.NullableSocialFeelingScoreLabel do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE social_feeling_results ALTER COLUMN score DROP NOT NULL"
    execute "ALTER TABLE social_feeling_results ALTER COLUMN label DROP NOT NULL"
  end

  def down do
    execute """
    UPDATE social_feeling_results
    SET score = 0.0, label = 'sin_datos'
    WHERE score IS NULL OR label IS NULL
    """

    execute "ALTER TABLE social_feeling_results ALTER COLUMN score SET NOT NULL"
    execute "ALTER TABLE social_feeling_results ALTER COLUMN label SET NOT NULL"
  end
end
