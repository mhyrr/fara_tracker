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

        <!-- The Origin Story -->
        <div class="bg-gradient-to-r from-teal-50 to-orange-50 border-l-4 border-teal-500 rounded-lg p-6 mb-8">
          <h2 class="text-2xl font-semibold text-gray-900 mb-4">🎧 How This Started</h2>
          <p class="text-gray-700 mb-4">
            Yesterday I listened to The Free Press podcast about foreign influence in America. The hosts talked about
            how reporters had to manually dig through FARA documents to trace the money. Sounded like
            horrible drudgery.
          </p>
          <p class="text-gray-700 mb-4">
            I checked out fara.gov to see what they were dealing with. A classic government website with thousands of
            scanned PDFs with terrible navigation. Absolutely unusable.
          </p>
          <p class="text-gray-700 mb-4">
            So I decided to DOGE it. I wanted to see a dashboard of foreign agent registrations and spending per country.
            This tool aggregates Foreign Agent Registration Act (FARA) documentation processes them with AI and builds that dashboard.
          </p>
          <p class="text-sm text-gray-600 italic">
            Inspired by: <a href="https://www.thefp.com/p/how-qatar-bought-america-f28" target="_blank" class="text-blue-600 hover:text-blue-800 underline">"How Qatar Bought America"</a> - The Free Press
          </p>
        </div>

        <!-- The Build Story -->
        <div class="bg-gradient-to-r from-blue-50 to-purple-50 border-l-4 border-blue-500 rounded-lg p-6 mb-8">
          <h2 class="text-2xl font-semibold text-gray-900 mb-4">⚡ Building It</h2>
          <p class="text-gray-700 mb-4">
            This whole thing was vibecoded in Cursor, from <code class="text-sm">mix phx.new</code>, schema, PDF and OpenAI processing, dashboard, domain name, and deployment in under 5 hours. I fed it some
            example PDFs, hooked it up to OpenAI, and wrote a prompt to pull out the important stuff: agent names,
            who they work for, how much they're getting paid.
          </p>
          <p class="text-gray-700 mb-4">
            Processed 8,000+ documents from 2023-2025. OpenAI bill so far: $3.10. Three bucks to automatically parse years
            of government paperwork that would take humans forever.
          </p>
          <p class="text-gray-700 mb-4">
            The goal was to see the big picture: <strong>which countries are spending
            the most under FARA?</strong>
          </p>
          <p class="text-gray-700">
            The data is pretty interesting. But the fact that it's 2025 and I could build this in an afternoon
            and deploy it was even cooler.
          </p>
        </div>

        <!-- The Reflection -->
        <div class="bg-gradient-to-r from-green-50 to-yellow-50 border-l-4 border-green-500 rounded-lg p-6 mb-8">
          <h2 class="text-2xl font-semibold text-gray-900 mb-4">🚀 The Vibe</h2>
          <p class="text-gray-700 mb-4">
            I know <b>LOTS</b> of developers way, way better than I am. But watching this unfold in a couple hours instead of days felt pretty superhuman.
          </p>
          <p class="text-gray-700 mb-4">
            I enjoyed some vibecoding before. I thought it was a useful assistant but I still wanted to control every line of code.
          </p>

          <p class="text-gray-700 mb-4">
            This is still just a toy. Production code is a whole different ballgame.
          </p>
          <p class="text-gray-700">
            But this is changing insanely quickly.
            I'm fine with the vibes.
          </p>
        </div>


        <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">🤖 AI Workflow</h2>
        <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 mb-6">
          <ol class="space-y-3 text-gray-700">
            <li><strong>1. Document Discovery:</strong> Scrape fara.gov for new PDF filings</li>
            <li><strong>2. Content Filtering:</strong> Skip marketing materials, focus on substantive reports</li>
            <li><strong>3. AI Processing:</strong> Send PDFs to OpenAI with structured prompts</li>
            <li><strong>4. Data Extraction:</strong> Extract agent names, foreign principals, compensation amounts</li>
            <li><strong>5. Database Storage:</strong> Normalize and store in PostgreSQL with country aggregation</li>
            <li><strong>6. Dashboard:</strong> Show spending by country</li>
          </ol>
        </div>

        <h2 class="text-2xl font-semibold text-gray-900 mt-8 mb-4">📊 Document Types</h2>

        <div class="grid md:grid-cols-2 gap-6 mt-6">
          <div class="border rounded-lg p-4" style="background-color: rgba(51, 193, 177, 0.1); border-color: #33c1b1;">
            <h3 class="font-semibold mb-2" style="color: #1A2F38;">✅ Processed Documents</h3>
            <ul class="text-sm space-y-1" style="color: #1A2F38;">
              <li>• Supplemental Statements (semi-annual activity reports)</li>
              <li>• Exhibit AB (compensation agreements)</li>
              <li>• Short Forms (brief activity filings)</li>
              <li>• Amendments (registration changes)</li>
              <li>• Registration Statements (initial filings)</li>
            </ul>
          </div>

          <div class="border rounded-lg p-4" style="background-color: rgba(245, 139, 0, 0.1); border-color: #F58B00;">
            <h3 class="font-semibold mb-2" style="color: #1A2F38;">❌ Filtered Out</h3>
            <ul class="text-sm space-y-1" style="color: #1A2F38;">
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
          <li><strong>AI Integration:</strong> OpenAI API for document processing</li>
          <li><strong>HTTP Client:</strong> Req library for document downloads</li>
          <li><strong>Data Processing:</strong> NimbleCSV for parsing FARA document registry</li>
          <li><strong>Development:</strong> Built entirely with Cursor AI coding assistant</li>
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
        <p class="text-sm text-gray-600 mt-4">
          Official source: <a href="https://efile.fara.gov/ords/fara/f?p=1381:1:9271288130869:::::" target="_blank" class="text-blue-600 hover:text-blue-800 underline">FARA eFiling Website</a> - U.S. Department of Justice
        </p>

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
