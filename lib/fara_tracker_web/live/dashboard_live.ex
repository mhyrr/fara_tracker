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

        <%= if Enum.empty?(@countries) do %>
          <div class="text-center py-12">
            <div class="text-gray-500">
              <p class="text-lg">No FARA registration data available yet.</p>
              <p class="mt-2">Run the data collection script to populate the database.</p>
            </div>
          </div>
        <% end %>
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
