defmodule FaraTracker.Fara.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fara_registrations" do
    field :agent_name, :string
    field :agent_address, :string
    field :foreign_principal, :string
    field :country, :string
    field :registration_date, :date
    field :total_compensation, :decimal
    field :latest_period_start, :date
    field :latest_period_end, :date
    field :services_description, :string
    field :status, :string, default: "active"

    timestamps()
  end

  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [
      :agent_name,
      :agent_address,
      :foreign_principal,
      :country,
      :registration_date,
      :total_compensation,
      :latest_period_start,
      :latest_period_end,
      :services_description,
      :status
    ])
    |> validate_required([:agent_name, :foreign_principal, :country])
    |> validate_number(:total_compensation, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, ["active", "inactive", "terminated"])
  end
end
