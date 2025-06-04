defmodule FaraTrackerWeb.AboutLive do
  use FaraTrackerWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-8 px-4">
      <div class="prose prose-lg max-w-none">
        <h1 class="text-4xl font-bold text-gray-900 mb-8">About FARA Tracker</h1>

        <p class="text-xl text-gray-600 mb-8 leading-relaxed">
          A Phoenix LiveView application for tracking foreign agent registrations under the Foreign Agent Registration Act (FARA).
          This tool aggregates and analyzes foreign influence spending by country with document scraping capabilities.
        </p>

        <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">🎯 Key Features</h2>
        <ul class="space-y-2 text-gray-700">
          <li><strong>Real-time Dashboard:</strong> Live view of foreign influence spending organized by country</li>
          <li><strong>Document Scraper:</strong> Automated PDF collection from the official FARA database</li>
          <li><strong>Smart Filtering:</strong> Focus on substantive documents while excluding marketing materials</li>
          <li><strong>PostgreSQL Database:</strong> Optimized schema for FARA data with aggregation capabilities</li>
        </ul>

        <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">📊 Document Types</h2>

        <div class="grid md:grid-cols-2 gap-6 mt-6">
          <div class="bg-green-50 border border-green-200 rounded-lg p-4">
            <h3 class="font-semibold text-green-800 mb-2">✅ Processed Documents</h3>
            <ul class="text-sm text-green-700 space-y-1">
              <li>• Supplemental Statements (semi-annual activity reports)</li>
              <li>• Exhibit AB (compensation agreements)</li>
              <li>• Short Forms (brief activity filings)</li>
              <li>• Amendments (registration changes)</li>
              <li>• Registration Statements (initial filings)</li>
            </ul>
          </div>

          <div class="bg-red-50 border border-red-200 rounded-lg p-4">
            <h3 class="font-semibold text-red-800 mb-2">❌ Filtered Out</h3>
            <ul class="text-sm text-red-700 space-y-1">
              <li>• Informational Materials (marketing/PR content)</li>
              <li>• Dissemination Reports (publication tracking)</li>
              <li>• Conflict of Interest documents</li>
            </ul>
          </div>
        </div>

        <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">🏗️ Technical Architecture</h2>
        <ul class="space-y-2 text-gray-700">
          <li><strong>Backend:</strong> Elixir/Phoenix with Ecto ORM</li>
          <li><strong>Frontend:</strong> Phoenix LiveView with Tailwind CSS</li>
          <li><strong>Database:</strong> PostgreSQL with aggregation views</li>
          <li><strong>HTTP Client:</strong> Req library for document downloads</li>
          <li><strong>Data Processing:</strong> NimbleCSV for parsing FARA document registry</li>
        </ul>

        <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">📚 Data Sources</h2>
        <p class="text-gray-700 mb-4">
          All data comes from official U.S. Department of Justice sources:
        </p>
        <ul class="space-y-2 text-gray-700">
          <li><strong>FARA eFiling Database:</strong> Official DOJ foreign agent registrations</li>
          <li><strong>Document Registry:</strong> Complete CSV export with direct PDF URLs</li>
          <li><strong>Legal Filings:</strong> Comprehensive collection of mandatory FARA submissions</li>
        </ul>

        <%!-- <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">🔮 Future Enhancements</h2>
        <ul class="space-y-2 text-gray-700">
          <li>• Enhanced AI integration for PDF data extraction</li>
          <li>• Advanced search and filtering capabilities</li>
          <li>• Trend analysis and data visualizations</li>
          <li>• Export and reporting features</li>
          <li>• Real-time FARA website monitoring</li>
        </ul> --%>

        <%!-- <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 mt-8">
          <h3 class="font-semibold text-blue-800 mb-2">About This Project</h3>
          <p class="text-blue-700 text-sm">
            Built as a demonstration of Phoenix LiveView capabilities, document processing pipelines,
            and data aggregation techniques. This project showcases real-time web interfaces and
            clean separation of concerns in modern Elixir applications.
          </p>
        </div> --%>

        <div class="mt-8 pt-6 border-t border-gray-200">
          <p class="text-sm text-gray-500">
            <a href="/" class="text-blue-600 hover:text-blue-800 font-medium">← Back to Dashboard</a>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
