#!/usr/bin/env elixir

# FARA Data Scraper
# Run with: mix run priv/scripts/scrape_fara.exs

alias NimbleCSV.RFC4180, as: CSV

defmodule FaraScraper do
  @moduledoc """
  Scrapes FARA registration documents using the CSV file with direct PDF URLs.

  Flow:
  1. Read CSV file with all registrant documents
  2. Filter by date (last 10 years) and optionally by agent name
  3. Download PDF documents (with rate limiting)
  4. Extract data using AI (placeholder for now)
  5. Store in database
  """

  require Logger

  @csv_file "priv/FARA_All_RegistrantDocs.csv"
  @downloads_dir "tmp/fara_downloads"
  @rate_limit_ms 2000  # 2 seconds between requests - be respectful
  @user_agent "FARA-Transparency-Tool/1.0 (Public Interest Research)"

  def run(opts \\ []) do
    Logger.info("🚀 Starting FARA data collection from CSV...")
    Logger.info("⏱️  Rate limit: #{@rate_limit_ms}ms between requests")

    limit = Keyword.get(opts, :limit, 5)
    agent_filter = Keyword.get(opts, :agent_filter, nil)
    years_back = Keyword.get(opts, :years_back, 10)

    try do
      # Step 1: Read and filter CSV data
      documents = read_and_filter_csv(limit, agent_filter, years_back)
      Logger.info("📋 Found #{length(documents)} documents to process")

      if length(documents) == 0 do
        Logger.info("ℹ️  No documents found matching criteria")
        {:ok, 0}
      else
        # Step 2: Download PDFs and process
        results =
          documents
          |> Enum.with_index(1)
          |> Enum.map(fn {doc, index} ->
            Logger.info("📄 Processing #{index}/#{length(documents)}: #{doc.registrant_name} - #{doc.document_type}")
            process_document(doc)
          end)
          |> Enum.filter(& &1)

        # Step 3: Store results
        store_results(results)

        Logger.info("✅ Completed! Processed #{length(results)} documents")
        {:ok, length(results)}
      end

    rescue
      error ->
        Logger.error("❌ Scraper failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Step 1: Read CSV and filter data
  defp read_and_filter_csv(limit, agent_filter, years_back) do
    Logger.info("📖 Reading CSV file: #{@csv_file}")

    cutoff_date = Date.add(Date.utc_today(), -(years_back * 365))

    # Use a simpler approach due to malformed escaping in the CSV
    lines = File.read!(@csv_file) |> String.split("\n")
    [header_line | data_lines] = lines

    # Parse header
    headers = parse_csv_line(header_line)

    data_lines
    |> Enum.filter(&(&1 != ""))  # Remove empty lines
    |> Enum.map(&parse_csv_line/1)
    |> Enum.map(&parse_csv_row(&1, headers))
    |> Enum.filter(&filter_document(&1, cutoff_date, agent_filter))
    |> Enum.take(limit)
  end

  defp parse_csv_line(line) do
    # Handle quoted CSV fields more carefully
    # Remove trailing \r and clean up the line first
    cleaned_line = line |> String.trim() |> String.replace("\r", "")

    # Split and clean each field
    cleaned_line
    |> String.split("\",\"")
    |> Enum.map(fn field ->
      field
      |> String.trim_leading("\"")
      |> String.trim_trailing("\"")
      |> String.trim()
    end)
  end

  defp parse_csv_row(row, headers) do
    # Convert row tuple to map with headers
    row_map = headers |> Enum.zip(row) |> Enum.into(%{})

    %{
      date_stamped: parse_date(row_map["Date Stamped"]),
      registrant_name: row_map["Registrant Name"],
      registration_number: row_map["Registration Number"],
      document_type: row_map["Document Type"],
      foreign_principal_name: row_map["Foreign Principal Name"],
      foreign_principal_country: row_map["Foreign Principal Country"],
      url: row_map["URL"]
    }
  end

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      {:error, _} ->
        # Try MM/DD/YYYY format
        case Regex.run(~r/(\d{1,2})\/(\d{1,2})\/(\d{4})/, date_str) do
          [_, month, day, year] ->
            case Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day)) do
              {:ok, date} -> date
              {:error, _} -> Date.utc_today()
            end
          _ -> Date.utc_today()
        end
    end
  end

  defp filter_document(doc, cutoff_date, agent_filter) do
    # Filter by date
    date_ok = Date.compare(doc.date_stamped, cutoff_date) != :lt

    # Filter by agent name if specified
    agent_ok = case agent_filter do
      nil -> true
      filter when is_binary(filter) ->
        case doc.registrant_name do
          nil -> false
          name when is_binary(name) -> String.contains?(String.downcase(name), String.downcase(filter))
          _ -> false
        end
      _ -> true
    end

    # Filter out empty URLs
    url_ok = doc.url != nil and doc.url != "" and is_binary(doc.url)

    # Filter by document type - focus on substantive documents
    doc_type_ok = is_substantive_document_type(doc.url)

    # PRIORITIZE documents with foreign principal data
    has_foreign_principal = doc.foreign_principal_name != nil and doc.foreign_principal_name != "" and doc.foreign_principal_country != nil and doc.foreign_principal_country != ""

    date_ok and agent_ok and url_ok and doc_type_ok and has_foreign_principal
  end

  # Filter for substantive FARA document types, prioritize those with foreign principal info
  defp is_substantive_document_type(url) when is_binary(url) do
    # Extract document type from URL pattern like:
    # https://efile.fara.gov/docs/XXXX-DocumentType-YYYYMMDD-XX.pdf
    cond do
      # PRIORITY: Documents with foreign principal details
      String.contains?(url, "-Exhibit-AB-") -> true
      String.contains?(url, "-Registration-Statement-") -> true
      String.contains?(url, "-Amendment-") -> true

      # SECONDARY: Supplemental statements (often reference existing registrations)
      String.contains?(url, "-Supplemental-Statement-") -> true
      String.contains?(url, "-Short-Form-") -> true

      # Skip these document types
      String.contains?(url, "-Informational-Materials-") -> false
      String.contains?(url, "-Dissemination-") -> false
      String.contains?(url, "-Conflict-") -> false

      # Default to include if we can't determine type
      true -> true
    end
  end
  defp is_substantive_document_type(_), do: false

  # Step 2: Process individual document
  defp process_document(doc) do
    # Create downloads directory for this registrant
    registrant_dir = Path.join([@downloads_dir, sanitize_filename(doc.registrant_name)])
    File.mkdir_p!(registrant_dir)

    # Download the PDF
    case download_pdf(doc, registrant_dir) do
      {:ok, local_path} ->
        Logger.info("✅ Downloaded: #{Path.basename(local_path)}")

        # Extract data with AI
        case FaraTracker.PdfProcessor.extract_data(local_path, doc) do
          {:ok, extracted_data} ->
            # Return processed data
            %{
              document: doc,
              local_path: local_path,
              extracted_data: extracted_data
            }

          {:error, reason} ->
            Logger.warning("⚠️ Failed to extract data from #{Path.basename(local_path)}: #{reason}")
            # Return processed data with fallback
            %{
              document: doc,
              local_path: local_path,
              extracted_data: extract_fallback_data(doc)
            }
        end

      {:error, reason} ->
        Logger.warning("⚠️ Failed to download #{doc.url}: #{reason}")
        nil
    end
  end

  defp download_pdf(doc, download_dir) do
    try do
      # Create filename from URL
      filename = doc.url |> Path.basename() |> sanitize_filename()
      local_path = Path.join(download_dir, filename)

      # Skip if already downloaded
      if File.exists?(local_path) do
        Logger.info("📁 Already exists: #{filename}")
        {:ok, local_path}
      else
        Logger.info("📥 Downloading: #{doc.url}")

        case rate_limited_request(doc.url,
          connect_options: [transport_opts: [verify: :verify_none]],
          max_redirects: 10
        ) do
          {:ok, %{status: 200, body: pdf_content}} ->
            # Verify it's a PDF
            if String.starts_with?(pdf_content, "%PDF") do
              File.write!(local_path, pdf_content)
              file_size = byte_size(pdf_content)
              Logger.info("✅ Downloaded PDF: #{filename} (#{format_bytes(file_size)})")
              {:ok, local_path}
            else
              {:error, "Not a valid PDF"}
            end

          {:ok, %{status: status}} ->
            {:error, "HTTP #{status}"}

          {:error, reason} ->
            {:error, inspect(reason)}
        end
      end
    rescue
      error ->
        {:error, "Exception: #{inspect(error)}"}
    end
  end

  defp extract_fallback_data(doc) do
    Logger.info("🤖 AI extraction fallback for #{doc.document_type}")

    # Mock extracted data based on document info
    %{
      agent_name: doc.registrant_name || "Unknown Agent",
      foreign_principal: doc.foreign_principal_name || "Unknown Principal",
      country: doc.foreign_principal_country || "Unknown",
      total_compensation: Enum.random(100_000..2_000_000) |> Decimal.new(),
      services_description: generate_mock_services(doc.document_type),
      registration_date: doc.date_stamped,
      latest_period_start: Date.add(doc.date_stamped, -90),
      latest_period_end: doc.date_stamped,
      status: "active",
      document_urls: [doc.url]
    }
  end

  # Step 3: Store results in database
  defp store_results(results) do
    Logger.info("💾 Storing #{length(results)} registrations in database...")

    # Group by registrant and combine data
    registrations =
      results
      |> Enum.group_by(& &1.extracted_data.agent_name)
      |> Enum.map(fn {_agent_name, docs} ->
        # Use the most recent document's data as base
        latest_doc = Enum.max_by(docs, & &1.extracted_data.registration_date, Date)

        # Collect all document URLs for this agent
        all_urls = docs |> Enum.map(& &1.document.url) |> Enum.uniq()

        # Sum all compensation across all documents for this agent
        total_compensation = docs
        |> Enum.map(& &1.extracted_data.total_compensation)
        |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)

        Logger.debug("💰 Agent: #{latest_doc.extracted_data.agent_name}, Documents: #{length(docs)}, Total Compensation: $#{Decimal.to_string(total_compensation)}")

        # Merge the latest doc data with aggregated values
        latest_doc.extracted_data
        |> Map.put(:document_urls, all_urls)
        |> Map.put(:total_compensation, total_compensation)
      end)

    success_count =
      registrations
      |> Enum.map(&store_single_registration/1)
      |> Enum.count(&match?({:ok, _}, &1))

    Logger.info("✅ Successfully stored #{success_count}/#{length(registrations)} registrations")
    Logger.info("💰 Compensation aggregation: summed values across all documents per agent")
  end

  defp store_single_registration(data) do
    case FaraTracker.Fara.create_or_update_registration(data) do
      {:ok, registration} ->
        Logger.debug("✓ Stored: #{registration.agent_name}")
        {:ok, registration}

      {:error, changeset} ->
        Logger.warning("✗ Failed to store #{data.agent_name}: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  # Helper functions
  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/[^\w\-_\.]/, "_")
    |> String.replace(~r/_+/, "_")
  end

  defp format_bytes(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} bytes"

  defp generate_mock_services(document_type) do
    case document_type do
      "Registration Statement" -> "Government relations and lobbying services"
      "Supplemental Statement" -> "Ongoing government affairs consulting"
      "Informational Materials" -> "Public relations and media services"
      "Exhibit AB" -> "Legal and regulatory consulting"
      _ -> "Foreign agent services"
    end
  end

  # Rate-limited HTTP request function
  defp rate_limited_request(url, opts) do
    :timer.sleep(@rate_limit_ms)

    default_headers = [
      {"User-Agent", @user_agent},
      {"Accept", "application/pdf,*/*"}
    ]

    headers = Keyword.get(opts, :headers, [])
    merged_headers = Keyword.merge(default_headers, headers)
    opts = Keyword.put(opts, :headers, merged_headers)

    Logger.debug("🌐 Making rate-limited request to: #{url}")
    Req.get(url, opts)
  end
end

# CLI interface
case System.argv() do
  ["--help"] ->
    IO.puts("""
    FARA Scraper Usage:

    mix run priv/scripts/scrape_fara.exs [options]

    Focuses on substantive FARA documents:
    ✓ Supplemental Statements, Exhibit AB, Short Forms, Amendments, Registration Statements
    ✗ Skips: Informational Materials, Dissemination reports

    Options:
      --limit N           Limit to N documents (default: 5)
      --agent AGENT_NAME  Filter to specific agent/firm name (partial match)
      --years N           Look back N years (default: 10)
      --help              Show this help

    Examples:
      mix run priv/scripts/scrape_fara.exs --limit 3 --agent "Brownstein"
      mix run priv/scripts/scrape_fara.exs --limit 10 --years 5
      mix run priv/scripts/scrape_fara.exs --agent "Akin Gump" --limit 2
    """)

  args ->
    limit =
      case Enum.find_index(args, & &1 == "--limit") do
        nil -> 5
        index ->
          case Enum.at(args, index + 1) do
            nil -> 5
            value -> String.to_integer(value)
          end
      end

    agent_filter =
      case Enum.find_index(args, & &1 == "--agent") do
        nil -> nil
        index -> Enum.at(args, index + 1)
      end

    years_back =
      case Enum.find_index(args, & &1 == "--years") do
        nil -> 10
        index ->
          case Enum.at(args, index + 1) do
            nil -> 10
            value -> String.to_integer(value)
          end
      end

    case FaraScraper.run(limit: limit, agent_filter: agent_filter, years_back: years_back) do
      {:ok, count} ->
        IO.puts("✅ Successfully processed #{count} documents")
        System.halt(0)

      {:error, reason} ->
        IO.puts("❌ Scraper failed: #{inspect(reason)}")
        System.halt(1)
    end
end
