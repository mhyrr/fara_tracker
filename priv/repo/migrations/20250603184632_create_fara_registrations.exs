defmodule FaraTracker.Repo.Migrations.CreateFaraRegistrations do
  use Ecto.Migration

  def up do
    create table(:fara_registrations) do
      add :agent_name, :string, null: false
      add :agent_address, :text
      add :foreign_principal, :string, null: false
      add :country, :string, null: false
      add :registration_date, :date
      add :total_compensation, :decimal, precision: 12, scale: 2, default: 0
      add :latest_period_start, :date
      add :latest_period_end, :date
      add :services_description, :text
      add :status, :string, default: "active"

      timestamps()
    end

    create index(:fara_registrations, [:country])
    create index(:fara_registrations, [:status])

    # Create aggregation view
    execute """
    CREATE VIEW country_summary AS
    SELECT
      country,
      COUNT(*) as agent_count,
      COALESCE(SUM(total_compensation), 0) as total_spending,
      MAX(updated_at) as last_updated
    FROM fara_registrations
    WHERE status = 'active'
    GROUP BY country
    ORDER BY total_spending DESC;
    """
  end

  def down do
    execute "DROP VIEW IF EXISTS country_summary;"
    drop table(:fara_registrations)
  end
end
