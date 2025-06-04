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
    <div class="max-w-full mx-auto py-6 sm:px-6 lg:px-8 bg-gray-50 min-h-screen">
      <div class="px-4 py-6 sm:px-0">
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">
            FARA Foreign Agent Tracker
          </h1>
          <div class="w-24 h-1 bg-gradient-to-r from-teal-500 to-orange-500 mx-auto rounded-full"></div>
        </div>

        <!-- Summary Stats -->
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-3 mb-10">
          <div class="bg-white overflow-hidden fara-card-shadow rounded-xl border-l-4 border-teal-500" style="border-left-color: #33c1b1;">
            <div class="p-6">
              <div class="flex items-center">
                <div class="p-3 rounded-full" style="background-color: rgba(51, 193, 177, 0.1);">
                  <.icon name="hero-globe-americas" class="h-6 w-6" style="color: #33c1b1;" />
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Countries</dt>
                    <dd class="text-2xl font-bold" style="color: #33c1b1;"><%= @total_countries %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden fara-card-shadow rounded-xl border-l-4 border-orange-500" style="border-left-color: #F58B00;">
            <div class="p-6">
              <div class="flex items-center">
                <div class="p-3 rounded-full" style="background-color: rgba(245, 139, 0, 0.1);">
                  <.icon name="hero-users" class="h-6 w-6" style="color: #F58B00;" />
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Agents</dt>
                    <dd class="text-2xl font-bold" style="color: #F58B00;"><%= @total_agents %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden fara-card-shadow rounded-xl border-l-4" style="border-left-color: #1A2F38;">
            <div class="p-6">
              <div class="flex items-center">
                <div class="p-3 rounded-full" style="background-color: rgba(26, 47, 56, 0.1);">
                  <.icon name="hero-currency-dollar" class="h-6 w-6" style="color: #1A2F38;" />
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">Total Spending</dt>
                    <dd class="text-2xl font-bold text-gray-900">$<%= format_currency(@total_spending) %></dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Countries Table -->
        <div class="bg-white fara-card-shadow-xl overflow-hidden rounded-xl">
          <div class="px-6 py-6 border-b fara-gradient-bg" style="border-color: #1A2F38;">
            <h3 class="text-xl leading-6 font-bold text-black">
              Foreign Influence by Country
            </h3>
            <p class="mt-2 max-w-2xl text-sm text-black opacity-80">
              Registered foreign agents and their reported compensation. Click on any country to view detailed agent information.
            </p>
          </div>

          <!-- Desktop Table Layout (hidden on mobile) -->
          <div class="hidden md:block border-t" style="border-color: #1A2F38;">
            <div class="overflow-x-auto fara-scrollbar">
              <table class="min-w-full table-auto divide-y" style="border-color: #1A2F38;">
                <thead style="background-color: rgba(26, 47, 56, 0.05);">
                  <tr>
                    <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider min-w-64" style="color: #1A2F38;">
                      Country / Agent
                    </th>
                    <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider min-w-24" style="color: #1A2F38;">
                      Count / Status
                    </th>
                    <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider min-w-40" style="color: #1A2F38;">
                      Total Compensation
                    </th>
                    <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider min-w-32" style="color: #1A2F38;">
                      Last Updated / Registration Date
                    </th>
                    <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider min-w-32" style="color: #1A2F38;">
                      Documents
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y" style="border-color: rgba(26, 47, 56, 0.1);">
                  <%= for country <- @countries do %>
                    <!-- Country Row (clickable) -->
                    <tr class="hover:bg-gradient-to-r hover:from-teal-50 hover:to-orange-50 cursor-pointer fara-transition"
                        phx-click="toggle_country"
                        phx-value-country={country.country}>
                      <td class="px-6 py-5 text-sm font-semibold text-gray-900">
                        <div class="flex items-center">
                          <!-- Expand/Collapse Icon -->
                          <div class="mr-3 flex-shrink-0">
                            <%= if MapSet.member?(@expanded_countries, country.country) do %>
                              <.icon name="hero-chevron-down" class="h-5 w-5 transition-transform duration-200" style="color: #33c1b1;" />
                            <% else %>
                              <.icon name="hero-chevron-right" class="h-5 w-5 transition-transform duration-200" style="color: #1A2F38;" />
                            <% end %>
                          </div>
                          <span class="text-lg"><%= country.country %></span>
                        </div>
                      </td>
                      <td class="px-6 py-5 text-sm">
                        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium text-white" style="background-color: #F58B00;">
                          <%= country.agent_count %>
                        </span>
                      </td>
                      <td class="px-6 py-5 text-sm font-mono font-semibold" style="color: #1A2F38;">
                        $<%= format_currency(country.total_spending) %>
                      </td>
                      <td class="px-6 py-5 text-sm text-gray-600">
                        <%= if country.last_updated, do: Calendar.strftime(country.last_updated, "%b %d, %Y"), else: "N/A" %>
                      </td>
                      <td class="px-6 py-5 text-sm text-gray-500">
                        <!-- Empty for country row -->
                      </td>
                    </tr>

                    <!-- Expanded Agent Details (Desktop) -->
                    <%= if MapSet.member?(@expanded_countries, country.country) do %>
                      <%= if length(Map.get(@country_agents, country.country, [])) > 0 do %>
                        <%= for agent <- Map.get(@country_agents, country.country, []) do %>
                          <tr class="border-l-4 fara-agent-row-bg fara-transition-slow" style="border-left-color: #33c1b1;">
                            <td class="px-6 py-4 text-sm text-gray-900">
                              <div class="ml-8 flex flex-col space-y-2">
                                <div class="font-semibold text-gray-900 text-base"><%= agent.agent_name %></div>
                                <div class="text-sm text-gray-600 leading-relaxed"><%= agent.foreign_principal %></div>
                              </div>
                            </td>
                            <td class="px-6 py-4 text-sm text-gray-500">
                              <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold text-white" style="background-color: #33c1b1;">
                                <%= String.capitalize(agent.status) %>
                              </span>
                            </td>
                            <td class="px-6 py-4 text-sm font-mono font-semibold" style="color: #F58B00;">
                              $<%= format_currency(agent.total_compensation) %>
                            </td>
                            <td class="px-6 py-4 text-sm text-gray-600">
                              <%= Calendar.strftime(agent.registration_date, "%b %d, %Y") %>
                            </td>
                            <td class="px-6 py-4 text-sm text-gray-500">
                              <%= if length(agent.document_urls || []) > 0 do %>
                                <div class="flex flex-wrap gap-2">
                                  <%= for {url, index} <- Enum.with_index(agent.document_urls) do %>
                                    <a href={url} target="_blank" class="p-2 rounded-lg fara-doc-link" title={"Document #{index + 1}"}>
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
                        <tr class="border-l-4" style="background-color: rgba(26, 47, 56, 0.05); border-left-color: #1A2F38;">
                          <td colspan="5" class="px-6 py-4 text-sm text-gray-500 text-center">
                            <div class="ml-8 italic">No active agents found for this country</div>
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
              <div class="border-t" style="border-color: rgba(26, 47, 56, 0.1);">
                <div class="px-6 py-5 hover:bg-gradient-to-r hover:from-teal-50 hover:to-orange-50 cursor-pointer fara-transition"
                     phx-click="toggle_country"
                     phx-value-country={country.country}>

                  <div class="flex items-center justify-between mb-4">
                    <div class="flex items-center">
                      <div class="mr-3 flex-shrink-0">
                        <%= if MapSet.member?(@expanded_countries, country.country) do %>
                          <.icon name="hero-chevron-down" class="h-5 w-5 transition-transform duration-200" style="color: #33c1b1;" />
                        <% else %>
                          <.icon name="hero-chevron-right" class="h-5 w-5 transition-transform duration-200" style="color: #1A2F38;" />
                        <% end %>
                      </div>
                      <h4 class="text-xl font-semibold text-gray-900"><%= country.country %></h4>
                    </div>
                  </div>

                  <div class="grid grid-cols-2 gap-6 text-sm">
                    <div class="flex items-center">
                      <span class="text-gray-600 font-medium">Agents:</span>
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold text-white ml-2" style="background-color: #F58B00;">
                        <%= country.agent_count %>
                      </span>
                    </div>
                    <div>
                      <span class="text-gray-600 font-medium">Spending:</span>
                      <div class="font-semibold font-mono text-lg mt-1" style="color: #1A2F38;">$<%= format_currency(country.total_spending) %></div>
                    </div>
                  </div>
                </div>

                <!-- Expanded Agent Details (Mobile) -->
                <%= if MapSet.member?(@expanded_countries, country.country) do %>
                  <%= if length(Map.get(@country_agents, country.country, [])) > 0 do %>
                    <%= for agent <- Map.get(@country_agents, country.country, []) do %>
                      <div class="px-6 py-4 border-l-4 fara-agent-row-bg fara-transition-slow" style="border-left-color: #33c1b1;">
                        <div class="mb-3">
                          <h5 class="font-semibold text-gray-900 text-base"><%= agent.agent_name %></h5>
                          <p class="text-sm text-gray-600 mt-1"><%= agent.foreign_principal %></p>
                        </div>

                        <div class="grid grid-cols-2 gap-4 text-sm mb-3">
                          <div>
                            <span class="text-gray-600 font-medium">Status:</span>
                            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-semibold text-white ml-1" style="background-color: #33c1b1;">
                              <%= String.capitalize(agent.status) %>
                            </span>
                          </div>
                          <div>
                            <span class="text-gray-600 font-medium">Compensation:</span>
                            <div class="font-semibold font-mono" style="color: #F58B00;">$<%= format_currency(agent.total_compensation) %></div>
                          </div>
                        </div>

                        <%= if length(agent.document_urls || []) > 0 do %>
                          <div class="flex justify-end">
                            <div class="flex space-x-2">
                              <%= for {url, index} <- Enum.with_index(agent.document_urls) do %>
                                <a href={url} target="_blank" class="p-2 rounded-lg fara-doc-link" title={"Document #{index + 1}"}>
                                  <.icon name="hero-document-text" class="h-4 w-4" />
                                </a>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  <% else %>
                    <div class="px-6 py-4 text-center text-sm text-gray-500 italic border-l-4" style="background-color: rgba(26, 47, 56, 0.05); border-left-color: #1A2F38;">
                      No active agents found for this country
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%= if Enum.empty?(@countries) do %>
          <div class="text-center py-16">
            <div class="max-w-md mx-auto">
              <div class="p-6 rounded-full mx-auto w-20 h-20 flex items-center justify-center mb-6" style="background-color: rgba(51, 193, 177, 0.1);">
                <.icon name="hero-document-magnifying-glass" class="h-10 w-10" style="color: #33c1b1;" />
              </div>
              <p class="text-xl font-semibold text-gray-900 mb-2">No FARA registration data available yet.</p>
              <p class="text-gray-600">Run the data collection script to populate the database.</p>
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
