# FARA Weekend Project - Phoenix Architecture

## Project Scope
Simple Phoenix app showing foreign influence spending by country. Single dashboard table with countries, lobbyist count, and total spending.

## Tech Stack
- **Backend**: Elixir/Phoenix
- **Database**: PostgreSQL
- **Frontend**: Phoenix LiveView
- **Deployment**: Fly.io
- **Data Collection**: EXS script with HTTPoison/Req

## Simplified Database Schema

```sql
-- Single flattened table approach
CREATE TABLE fara_registrations (
  id SERIAL PRIMARY KEY,
  agent_name VARCHAR(255) NOT NULL,
  agent_address TEXT,
  foreign_principal VARCHAR(255) NOT NULL,
  country VARCHAR(100) NOT NULL,
  registration_date DATE,
  total_compensation DECIMAL(12,2) DEFAULT 0,
  latest_period_start DATE,
  latest_period_end DATE,
  services_description TEXT,
  status VARCHAR(50) DEFAULT 'active',
  inserted_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_fara_country ON fara_registrations(country);
CREATE INDEX idx_fara_status ON fara_registrations(status);

-- Simple aggregation view
CREATE VIEW country_summary AS
SELECT 
  country,
  COUNT(*) as agent_count,
  SUM(total_compensation) as total_spending,
  MAX(updated_at) as last_updated
FROM fara_registrations 
WHERE status = 'active'
GROUP BY country
ORDER BY total_spending DESC;
```

## Phoenix App Structure

```
fara_tracker/
├── lib/
│   ├── fara_tracker/
│   │   ├── fara/
│   │   │   ├── registration.ex
│   │   │   └── fara.ex
│   │   └── fara_tracker.ex
│   ├── fara_tracker_web/
│   │   ├── controllers/
│   │   │   └── dashboard_controller.ex
│   │   ├── live/
│   │   │   └── dashboard_live.ex
│   │   └── templates/
│   └── mix.exs
├── priv/
│   ├── repo/migrations/
│   └── scripts/
│       └── scrape_fara.exs
└── config/
```

## Core Implementation

### 1. Schema (lib/fara_tracker/fara/registration.ex)
```elixir
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
    |> cast(attrs, [:agent_name, :foreign_principal, :country, :total_compensation, :services_description])
    |> validate_required([:agent_name, :foreign_principal, :country])
    |> validate_number(:total_compensation, greater_than_or_equal_to: 0)
  end
end
```

### 2. Context (lib/fara_tracker/fara.ex)
```elixir
defmodule FaraTracker.Fara do
  import Ecto.Query
  alias FaraTracker.Repo
  alias FaraTracker.Fara.Registration

  def list_registrations do
    Repo.all(Registration)
  end

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
    
    Repo.query!(query)
    |> format_country_results()
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

  def create_or_update_registration(attrs) do
    # Try to find existing registration by agent_name + foreign_principal
    case Repo.get_by(Registration, 
           agent_name: attrs[:agent_name], 
           foreign_principal: attrs[:foreign_principal]) do
      nil -> 
        %Registration{}
        |> Registration.changeset(attrs)
        |> Repo.insert()
      
      existing -> 
        existing
        |> Registration.changeset(attrs)
        |> Repo.update()
    end
  end
end
```

### 3. LiveView Dashboard (lib/fara_tracker_web/live/dashboard_live.ex)
```elixir
defmodule FaraTrackerWeb.DashboardLive do
  use FaraTrackerWeb, :live_view
  alias FaraTracker.Fara

  def mount(_params, _session, socket) do
    countries = Fara.get_country_summary()
    
    socket = 
      socket
      |> assign(:countries, countries)
      |> assign(:total_countries, length(countries))
      |> assign(:total_agents, Enum.sum(Enum.map(countries, & &1.agent_count)))
      |> assign(:total_spending, Enum.reduce(countries, Decimal.new("0"), &Decimal.add(&2, &1.total_spending)))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">
          FARA Foreign Agent Tracker
        </h1>
        
        <!-- Summary Stats -->
        <div class="grid grid-cols-1 gap-5 sm:grid-cols-3 mb-8">
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Countries</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @total_countries %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Agents</dt>
                    <dd class="text-lg font-medium text-gray-900"><%= @total_agents %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="p-5">
              <div class="flex items-center">
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Spending</dt>
                    <dd class="text-lg font-medium text-gray-900">$<%= format_currency(@total_spending) %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Countries Table -->
        <div class="bg-white shadow overflow-hidden sm:rounded-md">
          <div class="px-4 py-5 sm:px-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              Foreign Influence by Country
            </h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">
              Registered foreign agents and their reported compensation
            </p>
          </div>
          <div class="border-t border-gray-200">
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Country
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Active Agents
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Total Compensation
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Last Updated
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for country <- @countries do %>
                    <tr>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        <%= country.country %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= country.agent_count %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        $<%= format_currency(country.total_spending) %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        <%= if country.last_updated, do: Calendar.strftime(country.last_updated, "%b %d, %Y"), else: "N/A" %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_currency(amount) do
    amount
    |> Decimal.to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end
end
```

## Data Collection Script (priv/scripts/scrape_fara.exs)

```elixir
# Run with: mix run priv/scripts/scrape_fara.exs

Mix.install([
  {:req, "~> 0.4"},
  {:floki, "~> 0.35"},
  {:jason, "~> 1.4"}
])

defmodule FaraScraper do
  @base_url "https://efile.fara.gov/ords/fara/f"
  
  def run do
    IO.puts("Starting FARA data collection...")
    
    # Step 1: Get list of all registered agents
    agents = fetch_agent_list()
    IO.puts("Found #{length(agents)} agents")
    
    # Step 2: For each agent, extract key info
    agent_data = 
      agents
      |> Enum.take(10) # Start small for testing
      |> Enum.map(&process_agent/1)
      |> Enum.filter(& &1)
    
    # Step 3: Store in database
    store_agents(agent_data)
    
    IO.puts("Completed processing #{length(agent_data)} agents")
  end
  
  defp fetch_agent_list do
    # This would need to be customized based on the actual FARA site structure
    # For now, mock data
    [
      %{name: "Agent 1", url: "#{@base_url}?agent=1"},
      %{name: "Agent 2", url: "#{@base_url}?agent=2"}
    ]
  end
  
  defp process_agent(agent_info) do
    IO.puts("Processing: #{agent_info.name}")
    
    # Mock extraction - would use actual HTTP requests + parsing
    %{
      agent_name: agent_info.name,
      foreign_principal: "Sample Government",
      country: "Sample Country", 
      total_compensation: Decimal.new("50000"),
      services_description: "Lobbying services"
    }
  end
  
  defp store_agents(agent_data) do
    # Would connect to your app's repo and store data
    Enum.each(agent_data, fn data ->
      IO.inspect(data, label: "Would store")
    end)
  end
end

FaraScraper.run()
```

## Deployment Setup

### fly.toml
```toml
app = "fara-tracker"
primary_region = "iad"

[build]

[http_service]
  internal_port = 4000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true

[[vm]]
  memory = "1gb"
  cpu_kind = "shared"
  cpus = 1

[env]
  PHX_HOST = "fara-tracker.fly.dev"
  PORT = "4000"
```

## Weekend Implementation Plan

### Saturday Morning (2-3 hours)
1. `mix phx.new fara_tracker --database postgres`
2. Set up basic schema and migration
3. Create dashboard LiveView with mock data

### Saturday Afternoon (3-4 hours)  
1. Build basic scraper script
2. Test data extraction from a few sample pages
3. Hook up real data to dashboard

### Sunday (2-3 hours)
1. Deploy to Fly.io
2. Run full data collection
3. Polish dashboard styling

## Total: ~8 hours for MVP

This gives you a working FARA tracker showing countries, agent counts, and spending totals - perfect weekend scope!