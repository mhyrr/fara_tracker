#!/usr/bin/env elixir

# Test Exhibit AB document extraction
doc_metadata = %{
  registrant_name: "Nelson Mullins Riley Scarborough LLP",
  foreign_principal_name: "",
  foreign_principal_country: "",
  document_type: "Exhibit AB",
  date_stamped: ~D[2025-05-28]
}

IO.puts("🎯 Testing Exhibit AB document extraction...")

case FaraTracker.PdfProcessor.extract_data("tmp/fara_downloads/Nelson_Mullins_Riley_Scarborough_LLP/5928-Exhibit-AB-20250528-62.pdf", doc_metadata) do
  {:ok, data} ->
    IO.puts("✅ Successfully extracted from Exhibit AB:")
    IO.puts("Agent: #{data.agent_name}")
    IO.puts("Foreign Principal: #{data.foreign_principal}")
    IO.puts("Country: #{data.country}")
    IO.puts("Compensation: $#{data.total_compensation}")
    IO.puts("Services: #{data.services_description}")

  {:error, reason} ->
    IO.puts("❌ Error: #{reason}")
end
