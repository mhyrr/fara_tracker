#!/usr/bin/env elixir

# Test PDF Processor with OpenAI
# Run with: OPENAI_API_KEY=your_key mix run priv/scripts/test_pdf_processor.exs

defmodule PdfProcessorTest do
  require Logger

  def run do
    Logger.info("🧪 Testing PDF Processor with OpenAI integration...")

    # Check if API key is set
    case System.get_env("OPENAI_API_KEY") do
      nil ->
        IO.puts("❌ OPENAI_API_KEY environment variable not set!")
        IO.puts("Run: export OPENAI_API_KEY=your_key_here")
        System.halt(1)

      key when byte_size(key) < 10 ->
        IO.puts("❌ OPENAI_API_KEY seems invalid (too short)")
        System.halt(1)

      _key ->
        IO.puts("✅ OpenAI API key found")
    end

    # Find some downloaded PDFs to test with
    downloads_dir = "tmp/fara_downloads"

    case find_test_pdf(downloads_dir) do
      nil ->
        IO.puts("❌ No PDFs found in #{downloads_dir}")
        IO.puts("Run the scraper first: mix run priv/scripts/scrape_fara.exs --limit 2")
        System.halt(1)

      {pdf_path, size} ->
        IO.puts("✅ Found test PDF: #{Path.basename(pdf_path)} (#{format_bytes(size)})")

        # Create mock document metadata
        doc_metadata = %{
          registrant_name: "Test Agent LLC",
          foreign_principal_name: "Test Foreign Principal",
          foreign_principal_country: "Test Country",
          document_type: "Supplemental Statement",
          date_stamped: Date.utc_today(),
          url: "https://example.com/test.pdf"
        }

        # Test the PDF processor
        case FaraTracker.PdfProcessor.extract_data(pdf_path, doc_metadata) do
          {:ok, extracted_data} ->
            IO.puts("✅ Successfully extracted data!")
            IO.puts("\nExtracted Data:")
            IO.puts("Agent: #{extracted_data.agent_name}")
            IO.puts("Foreign Principal: #{extracted_data.foreign_principal}")
            IO.puts("Country: #{extracted_data.country}")
            IO.puts("Compensation: $#{extracted_data.total_compensation}")
            IO.puts("Services: #{extracted_data.services_description}")
            IO.puts("Registration Date: #{extracted_data.registration_date}")
            IO.puts("Status: #{extracted_data.status}")

          {:error, reason} ->
            IO.puts("❌ Failed to extract data: #{inspect(reason)}")
            System.halt(1)
        end
    end

    IO.puts("\n🎉 PDF Processor test completed successfully!")
  end

  defp find_test_pdf(downloads_dir) do
    case File.ls(downloads_dir) do
      {:ok, subdirs} ->
        # Look for PDFs in subdirectories
        subdirs
        |> Enum.find_value(fn subdir ->
          subdir_path = Path.join(downloads_dir, subdir)

          if File.dir?(subdir_path) do
            case File.ls(subdir_path) do
              {:ok, files} ->
                files
                |> Enum.find(fn file -> String.ends_with?(file, ".pdf") end)
                |> case do
                  nil -> nil
                  pdf_file ->
                    pdf_path = Path.join(subdir_path, pdf_file)
                    size = File.stat!(pdf_path).size
                    {pdf_path, size}
                end

              {:error, _} -> nil
            end
          else
            nil
          end
        end)

      {:error, _} -> nil
    end
  end

  defp format_bytes(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} bytes"
end

# Run the test
PdfProcessorTest.run()
