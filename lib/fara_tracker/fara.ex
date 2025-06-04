defmodule FaraTracker.Fara do
  @moduledoc """
  The Fara context for managing foreign agent registrations.
  """

  import Ecto.Query, warn: false
  alias FaraTracker.Repo
  alias FaraTracker.Fara.Registration

  @doc """
  Returns the list of registrations.
  """
  def list_registrations do
    Repo.all(Registration)
  end

  @doc """
  Gets a single registration.
  """
  def get_registration!(id), do: Repo.get!(Registration, id)

  @doc """
  Gets country summary data for the dashboard.
  """
  def get_country_summary do
    query = """
    SELECT
      country,
      COUNT(*) as agent_count,
      COALESCE(SUM(total_compensation), 0) as total_spending,
      MAX(updated_at) as last_updated
    FROM fara_registrations
    WHERE status = 'active'
    GROUP BY country
    ORDER BY total_spending DESC
    """

    case Repo.query(query) do
      {:ok, result} -> format_country_results(result)
      {:error, _} -> []
    end
  end

  defp format_country_results(%{rows: rows}) do
    Enum.map(rows, fn [country, count, spending, updated] ->
      %{
        country: country,
        agent_count: count,
        total_spending: Decimal.new(spending || "0"),
        last_updated: updated
      }
    end)
  end

  @doc """
  Creates a registration.
  """
  def create_registration(attrs \\ %{}) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a registration.
  """
  def update_registration(%Registration{} = registration, attrs) do
    registration
    |> Registration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a registration.
  """
  def delete_registration(%Registration{} = registration) do
    Repo.delete(registration)
  end

  @doc """
  Creates or updates a registration based on agent_name and foreign_principal.
  """
  def create_or_update_registration(attrs) do
    case Repo.get_by(Registration,
           agent_name: attrs[:agent_name],
           foreign_principal: attrs[:foreign_principal]) do
      nil ->
        create_registration(attrs)

      existing ->
        update_registration(existing, attrs)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking registration changes.
  """
  def change_registration(%Registration{} = registration, attrs \\ %{}) do
    Registration.changeset(registration, attrs)
  end

  @doc """
  Gets detailed agent information for a specific country.
  """
  def get_agents_by_country(country) do
    query = from r in Registration,
             where: r.country == ^country and r.status == "active",
             order_by: [desc: r.registration_date, asc: r.agent_name],
             select: %{
               id: r.id,
               agent_name: r.agent_name,
               foreign_principal: r.foreign_principal,
               status: r.status,
               registration_date: r.registration_date,
               total_compensation: r.total_compensation,
               latest_period_end: r.latest_period_end,
               document_urls: r.document_urls
             }

    Repo.all(query)
  end
end
