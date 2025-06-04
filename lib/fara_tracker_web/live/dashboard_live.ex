defmodule FaraTrackerWeb.DashboardLive do
  use FaraTrackerWeb, :live_view
  alias FaraTracker.Fara

  def mount(_params, _session, socket) do
    countries = Fara.get_country_summary()

    socket =
      socket
      |> assign(:countries, countries)
      |> assign(:expanded_countries, MapSet.new())
      |> assign(:country_agents, %{})
      |> assign(:total_countries, length(countries))
      |> assign(:total_agents, Enum.sum(Enum.map(countries, & &1.agent_count)))
      |> assign(:total_spending, Enum.reduce(countries, Decimal.new("0"), &Decimal.add(&2, &1.total_spending)))

    {:ok, socket}
  end

  def handle_event("toggle_country", %{"country" => country}, socket) do
    expanded_countries = socket.assigns.expanded_countries
    country_agents = socket.assigns.country_agents

    {new_expanded, new_agents} =
      if MapSet.member?(expanded_countries, country) do
        # Collapse: remove from expanded set and clear agents data
        {MapSet.delete(expanded_countries, country), Map.delete(country_agents, country)}
      else
        # Expand: add to expanded set and load agents data
        agents = Fara.get_agents_by_country(country)
        {MapSet.put(expanded_countries, country), Map.put(country_agents, country, agents)}
      end

    socket =
      socket
      |> assign(:expanded_countries, new_expanded)
      |> assign(:country_agents, new_agents)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-full mx-auto py-6 sm:px-6 lg:px-8">
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
              Registered foreign agents and their reported compensation. Click on any country to view detailed agent information.
            </p>
          </div>

          <!-- Desktop Table Layout (hidden on mobile) -->
          <div class="hidden md:block border-t border-gray-200">
            <div class="overflow-x-auto">
              <table class="min-w-full table-auto divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-64">
                      Country / Agent
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-24">
                      Count / Status
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-40">
                      Total Compensation
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-32">
                      Last Updated / Registration Date
                    </th>
                    <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider min-w-32">
                      Documents
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for country <- @countries do %>
                    <!-- Country Row (clickable) -->
                    <tr class="hover:bg-gray-50 cursor-pointer transition-colors"
                        phx-click="toggle_country"
                        phx-value-country={country.country}>
                      <td class="px-4 py-4 text-sm font-medium text-gray-900">
                        <div class="flex items-center">
                          <!-- Expand/Collapse Icon -->
                          <div class="mr-2 flex-shrink-0">
                            <%= if MapSet.member?(@expanded_countries, country.country) do %>
                              <.icon name="hero-chevron-down" class="h-4 w-4 text-gray-400" />
                            <% else %>
                              <.icon name="hero-chevron-right" class="h-4 w-4 text-gray-400" />
                            <% end %>
                          </div>
                          <span><%= country.country %></span>
                        </div>
                      </td>
                      <td class="px-4 py-4 text-sm text-gray-500">
                        <%= country.agent_count %>
                      </td>
                      <td class="px-4 py-4 text-sm text-gray-500 font-mono">
                        $<%= format_currency(country.total_spending) %>
                      </td>
                      <td class="px-4 py-4 text-sm text-gray-500">
                        <%= if country.last_updated, do: Calendar.strftime(country.last_updated, "%b %d, %Y"), else: "N/A" %>
                      </td>
                      <td class="px-4 py-4 text-sm text-gray-500">
                        <!-- Empty for country row -->
                      </td>
                    </tr>

                    <!-- Expanded Agent Details (Desktop) -->
                    <%= if MapSet.member?(@expanded_countries, country.country) do %>
                      <%= if length(Map.get(@country_agents, country.country, [])) > 0 do %>
                        <%= for agent <- Map.get(@country_agents, country.country, []) do %>
                          <tr class="bg-gray-50 border-l-4 border-blue-200">
                            <td class="px-4 py-3 text-sm text-gray-900">
                              <div class="ml-6 flex flex-col space-y-1">
                                <div class="font-medium text-gray-900"><%= agent.agent_name %></div>
                                <div class="text-xs text-gray-500 leading-relaxed"><%= agent.foreign_principal %></div>
                              </div>
                            </td>
                            <td class="px-4 py-3 text-sm text-gray-500">
                              <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                <%= String.capitalize(agent.status) %>
                              </span>
                            </td>
                            <td class="px-4 py-3 text-sm text-gray-500 font-mono">
                              $<%= format_currency(agent.total_compensation) %>
                            </td>
                            <td class="px-4 py-3 text-sm text-gray-500">
                              <%= Calendar.strftime(agent.registration_date, "%b %d, %Y") %>
                            </td>
                            <td class="px-4 py-3 text-sm text-gray-500">
                              <%= if length(agent.document_urls || []) > 0 do %>
                                <div class="flex flex-wrap gap-1">
                                  <%= for {url, index} <- Enum.with_index(agent.document_urls) do %>
                                    <a href={url} target="_blank" class="text-blue-600 hover:text-blue-800 flex-shrink-0" title={"Document #{index + 1}"}>
                                      <.icon name="hero-document-text" class="h-4 w-4" />
                                    </a>
                                  <% end %>
                                </div>
                              <% else %>
                                <span class="text-gray-400">No docs</span>
                              <% end %>
                            </td>
                          </tr>
                        <% end %>
                      <% else %>
                        <tr class="bg-gray-50 border-l-4 border-gray-200">
                          <td colspan="5" class="px-4 py-3 text-sm text-gray-500 text-center">
                            <div class="ml-6 italic">No active agents found for this country</div>
                          </td>
                        </tr>
                      <% end %>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Mobile Card Layout (hidden on desktop) -->
          <div class="block md:hidden">
            <%= for country <- @countries do %>
              <div class="border-t border-gray-200">
                <div class="px-4 py-4 hover:bg-gray-50 cursor-pointer transition-colors"
                     phx-click="toggle_country"
                     phx-value-country={country.country}>

                  <div class="flex items-center justify-between mb-3">
                    <div class="flex items-center">
                      <div class="mr-2 flex-shrink-0">
                        <%= if MapSet.member?(@expanded_countries, country.country) do %>
                          <.icon name="hero-chevron-down" class="h-4 w-4 text-gray-400" />
                        <% else %>
                          <.icon name="hero-chevron-right" class="h-4 w-4 text-gray-400" />
                        <% end %>
                      </div>
                      <h4 class="text-lg font-medium text-gray-900"><%= country.country %></h4>
                    </div>
                  </div>

                  <div class="grid grid-cols-2 gap-6 text-sm">
                    <div>
                      <span class="text-gray-500">Agents:</span>
                      <span class="font-medium ml-1"><%= country.agent_count %></span>
                    </div>
                    <div>
                      <span class="text-gray-500">Spending:</span>
                      <div class="font-medium font-mono ml-1">$<%= format_currency(country.total_spending) %></div>
                    </div>
                  </div>
                </div>

                <!-- Expanded Agent Details (Mobile) -->
                <%= if MapSet.member?(@expanded_countries, country.country) do %>
                  <%= if length(Map.get(@country_agents, country.country, [])) > 0 do %>
                    <%= for agent <- Map.get(@country_agents, country.country, []) do %>
                      <div class="bg-gray-50 px-4 py-3 border-l-4 border-blue-200">
                        <div class="mb-2">
                          <h5 class="font-medium text-gray-900 text-sm"><%= agent.agent_name %></h5>
                          <p class="text-xs text-gray-600 mt-1"><%= agent.foreign_principal %></p>
                        </div>

                        <div class="grid grid-cols-2 gap-4 text-xs mb-2">
                          <div>
                            <span class="text-gray-500">Status:</span>
                            <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800 ml-1">
                              <%= String.capitalize(agent.status) %>
                            </span>
                          </div>
                          <div>
                            <span class="text-gray-500">Compensation:</span>
                            <div class="font-medium font-mono">$<%= format_currency(agent.total_compensation) %></div>
                          </div>
                        </div>

                        <%= if length(agent.document_urls || []) > 0 do %>
                          <div class="flex justify-end">
                            <div class="flex space-x-1">
                              <%= for {url, index} <- Enum.with_index(agent.document_urls) do %>
                                <a href={url} target="_blank" class="text-blue-600 hover:text-blue-800" title={"Document #{index + 1}"}>
                                  <.icon name="hero-document-text" class="h-4 w-4" />
                                </a>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  <% else %>
                    <div class="bg-gray-50 px-4 py-3 text-center text-sm text-gray-500 italic">
                      No active agents found for this country
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
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
