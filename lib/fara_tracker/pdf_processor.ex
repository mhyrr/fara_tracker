defmodule FaraTracker.PdfProcessor do
  @moduledoc """
  Processes FARA PDF documents using OpenAI to extract structured data.
  """

  require Logger

  @doc """
  Extracts data from a PDF file using OpenAI.
  Returns structured data matching the Registration schema.
  """
  def extract_data(pdf_path, document_metadata) do
    Logger.info("🤖 Processing PDF with OpenAI: #{Path.basename(pdf_path)}")

    try do
      # First, try to extract text from PDF (simplified approach)
      case extract_text_from_pdf(pdf_path) do
        {:ok, text} when byte_size(text) > 100 ->
          # Use OpenAI to extract structured data
          extract_with_openai(text, document_metadata)

        {:ok, _short_text} ->
          Logger.warning("⚠️ PDF text too short, using metadata fallback")
          {:ok, fallback_extraction(document_metadata)}

        {:error, reason} ->
          Logger.warning("⚠️ PDF text extraction failed: #{reason}, using metadata fallback")
          {:ok, fallback_extraction(document_metadata)}
      end

    rescue
      error ->
        Logger.error("❌ PDF processing failed: #{inspect(error)}")
        {:ok, fallback_extraction(document_metadata)}
    end
  end

  # Extract text from PDF (basic approach - reads first few KB)
  defp extract_text_from_pdf(pdf_path) do
    try do
      # First, try using pdftotext if available (much better than binary parsing)
      case System.cmd("pdftotext", [pdf_path, "-"], stderr_to_stdout: true) do
        {text, 0} when byte_size(text) > 100 ->
          Logger.debug("📄 Used pdftotext for extraction")
          Logger.debug("📄 Full document length: #{byte_size(text)} bytes")

          # Send the full document - no truncation needed for reasonable token costs
          {:ok, text}

        {_error, _} ->
          Logger.debug("📄 pdftotext failed, falling back to binary parsing")
          fallback_pdf_extraction(pdf_path)
      end
    rescue
      _ ->
        Logger.debug("📄 pdftotext not available, using binary parsing")
        fallback_pdf_extraction(pdf_path)
    end
  end

  # Fallback PDF extraction using binary parsing
  defp fallback_pdf_extraction(pdf_path) do
    try do
      # Read PDF file
      case File.read(pdf_path) do
        {:ok, pdf_content} ->
          # Simple text extraction - look for readable text in PDF
          # This is a basic approach; for production you'd want a proper PDF parser
          text = extract_readable_text(pdf_content)
          {:ok, text}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error -> {:error, inspect(error)}
    end
  end

  # Basic text extraction from PDF binary
  defp extract_readable_text(pdf_binary) do
    # Extract text between stream objects and clean it up
    text = pdf_binary
    |> String.split("stream")
    |> Enum.map(&extract_text_chunk/1)
    |> Enum.join(" ")
    |> String.replace(~r/[^\x20-\x7E\s]/, " ")  # Keep only printable ASCII
    |> String.replace(~r/\s+/, " ")              # Normalize whitespace
    |> String.trim()
    |> String.slice(0, 20000)  # Increase limit to 20KB for better extraction

    # Also try to extract text that might contain compensation keywords
    compensation_text = extract_compensation_sections(pdf_binary)

    # Combine general text with specific compensation searches
    combined_text = text <> " " <> compensation_text

    Logger.debug("📝 Extracted PDF text (first 500 chars): #{String.slice(combined_text, 0, 500)}")
    Logger.debug("🔍 Looking for compensation patterns...")

    combined_text
  end

  defp extract_text_chunk(chunk) do
    chunk
    |> String.split("endstream")
    |> List.first()
    |> String.replace(~r/<<[^>]*>>/, "")  # Remove PDF objects
    |> String.replace(~r/\/[A-Za-z]+/, "") # Remove PDF commands
    |> String.trim()
  end

  # Try to find sections that might contain compensation information
  defp extract_compensation_sections(pdf_binary) do
    # Look for text around compensation keywords
    compensation_keywords = [
      "compensation", "paid", "sum of", "month", "monthly", "annual", "yearly",
      "quarter", "quarterly", "fee", "retainer", "salary", "payment"
    ]

    # Split by pages (rough approach using page indicators)
    pages = String.split(pdf_binary, ~r/Page \d+|page \d+/i)

    # Look for pages containing compensation keywords
    compensation_pages = pages
    |> Enum.filter(fn page ->
      page_lower = String.downcase(page)
      Enum.any?(compensation_keywords, &String.contains?(page_lower, &1))
    end)
    |> Enum.map(&extract_text_chunk/1)
    |> Enum.join(" ")

    compensation_pages
  end

  # Use OpenAI to extract structured data
  defp extract_with_openai(text, document_metadata) do
    prompt = build_extraction_prompt(text, document_metadata)

    # Create OpenAI client
    case System.get_env("OPENAI_API_KEY") do
      nil ->
        Logger.error("❌ OPENAI_API_KEY not set")
        {:ok, fallback_extraction(document_metadata)}

      api_key ->
        openai = OpenaiEx.new(api_key)
                |> OpenaiEx.with_finch_name(FaraTracker.Finch)
                |> OpenaiEx.with_receive_timeout(60_000)

        chat_req = OpenaiEx.Chat.Completions.new(
          model: "gpt-4o-mini",
          messages: [
            OpenaiEx.ChatMessage.system(system_prompt()),
            OpenaiEx.ChatMessage.user(prompt)
          ],
          max_tokens: 2000,
          temperature: 0.1
        )

        case OpenaiEx.Chat.Completions.create(openai, chat_req) do
          {:ok, %{"choices" => [%{"message" => %{"content" => response}} | _]}} ->
            Logger.debug("🔍 RAW OpenAI Response: #{response}")
            parse_openai_response(response, document_metadata)

          {:error, reason} ->
            Logger.error("❌ OpenAI API error: #{inspect(reason)}")
            {:ok, fallback_extraction(document_metadata)}

          unexpected ->
            Logger.error("❌ Unexpected OpenAI response: #{inspect(unexpected)}")
            {:ok, fallback_extraction(document_metadata)}
        end
    end
  end

  defp system_prompt do
    """
    You are a FARA document analysis expert. Extract key information from Foreign Agent Registration Act documents.

    CRITICAL: Focus on finding foreign principal information. Look specifically for:
    - Province names (e.g., "Province of Saskatchewan", "Province of Ontario")
    - Government entities (e.g., "Government of Canada", "Ministry of...", "Department of...")
    - Country names in any form (e.g., "Canada", "CANADA", "Republic of...", "Kingdom of...")
    - Foreign corporations or organizations
    - Any entity that is NOT a US entity

    COMPENSATION EXTRACTION: CRITICAL - Look VERY carefully for compensation patterns. These are often on the last pages or in exhibit sections.
    Look for these EXACT patterns:
    - "Contractor will be paid a sum of $X a month" → X * 12 for annual
    - "paid a sum of $X month" → X * 12 for annual
    - "Compensation: $X per month" → X * 12 for annual
    - "Salary: $X per annum" → use as annual value
    - "$X monthly commission" → X * 12
    - "$X quarterly" → X * 4
    - "Thing of value: $X" → add to total
    - "retainer of $X" → add to total
    - "fee of $X per month" → X * 12
    - Any dollar amounts followed by "month", "monthly", "per month", "a month"
    - Any dollar amounts followed by "year", "yearly", "per year", "per annum", "annual"
    - Look in sections like "Compensation", "Thing of Value", "Fees", "Payment", "Exhibit"

    SEARCH AGGRESSIVELY for dollar signs ($) in the text - each one might be compensation!

    Common patterns to look for:
    - "Foreign Principal: [NAME]"
    - "Name of Foreign Principal: [NAME]"
    - "Principal: [NAME]"
    - "On behalf of: [NAME]"
    - "Representing: [NAME]"
    - "Client: [NAME]"
    - Province/state names outside the US
    - Government departments of foreign countries

    Return ONLY a JSON object with these exact fields (no additional text or explanation):
    {
      "agent_name": "string - the registrant/agent name",
      "agent_address": "string - agent's business address",
      "foreign_principal": "string - the foreign principal name (MUST extract if present - look carefully for provinces, governments, foreign entities)",
      "country": "string - foreign principal's country (MUST extract if present - look for country names, infer from provinces like Saskatchewan=Canada)",
      "compensation_entries": [
        {
          "amount": "number - the dollar amount (no $ sign)",
          "period": "string - annual/monthly/quarterly/one-time",
          "description": "string - description of the compensation"
        }
      ],
      "total_compensation": "number - total annual compensation (convert all entries to yearly and sum)",
      "services_description": "string - description of services provided",
      "registration_date": "string - registration date in YYYY-MM-DD format",
      "latest_period_start": "string - reporting period start in YYYY-MM-DD format",
      "latest_period_end": "string - reporting period end in YYYY-MM-DD format",
      "status": "active"
    }

    COMPENSATION CALCULATION EXAMPLES:
    - "paid a sum of $50,000 a month" → 50000 * 12 = 600,000 annual
    - "$5,000 per month" → 5000 * 12 = 60,000 annual
    - "$100,000 per annum" → 100,000 annual
    - "$25,000 quarterly retainer" → 25,000 * 4 = 100,000 annual
    - "No compensation" → 0

    EXAMPLES of foreign principals to extract:
    - "Province of Saskatchewan" → foreign_principal: "Province of Saskatchewan", country: "Canada"
    - "Government of Canada" → foreign_principal: "Government of Canada", country: "Canada"
    - "Republic of France" → foreign_principal: "Republic of France", country: "France"
    - "Toyota Motor Corporation" → foreign_principal: "Toyota Motor Corporation", country: "Japan" (if context suggests it's Japanese)

    If you cannot find foreign principal or compensation information in the text, return empty strings "" or 0, do NOT make up information.
    """
  end

  defp build_extraction_prompt(text, metadata) do
    """
    Document Type: #{metadata.document_type}
    Registrant: #{metadata.registrant_name}
    Foreign Principal: #{metadata.foreign_principal_name}
    Country: #{metadata.foreign_principal_country}
    Date Stamped: #{metadata.date_stamped}

    Document Content:
    #{text}

    Extract the required information as JSON.
    """
  end

  defp parse_openai_response(response, document_metadata) do
    try do
      # Try to extract JSON from the response
      json_text = extract_json_from_response(response)

      case Jason.decode(json_text) do
        {:ok, data} when is_map(data) ->
          # Convert to atoms and validate
          extracted_data = %{
            agent_name: get_string_value(data, "agent_name") || document_metadata.registrant_name || "Unknown Agent",
            agent_address: get_string_value(data, "agent_address"),
            foreign_principal: get_string_value(data, "foreign_principal") ||
                              (if document_metadata.foreign_principal_name != "", do: document_metadata.foreign_principal_name, else: nil) ||
                              "Unknown Principal",
            country: get_string_value(data, "country") ||
                     (if document_metadata.foreign_principal_country != "", do: document_metadata.foreign_principal_country, else: nil) ||
                     "Unknown",
            compensation_entries: get_compensation_entries(data["compensation_entries"]),
            total_compensation: calculate_final_compensation(data),
            services_description: get_string_value(data, "services_description"),
            registration_date: parse_date_value(data["registration_date"]) || document_metadata.date_stamped,
            latest_period_start: parse_date_value(data["latest_period_start"]) || Date.add(document_metadata.date_stamped, -90),
            latest_period_end: parse_date_value(data["latest_period_end"]) || document_metadata.date_stamped,
            status: "active"
          }

          Logger.debug("🔍 OpenAI extracted: #{inspect(data)}")
          Logger.debug("🔍 Document metadata: foreign_principal=#{document_metadata.foreign_principal_name}, country=#{document_metadata.foreign_principal_country}")
          Logger.debug("🔍 Final data: foreign_principal=#{extracted_data.foreign_principal}, country=#{extracted_data.country}")

          Logger.info("✅ Successfully extracted data for #{extracted_data.agent_name}")
          {:ok, extracted_data}

        {:error, _json_error} ->
          Logger.warning("⚠️ Failed to parse OpenAI JSON response, using fallback")
          {:ok, fallback_extraction(document_metadata)}
      end
    rescue
      error ->
        Logger.error("❌ Error parsing OpenAI response: #{inspect(error)}")
        {:ok, fallback_extraction(document_metadata)}
    end
  end

  defp extract_json_from_response(response) do
    # Look for JSON object in the response, handling markdown code blocks
    cond do
      # First try to extract from ```json code blocks
      String.contains?(response, "```json") ->
        case Regex.run(~r/```json\s*(\{.*?\})\s*```/s, response) do
          [_, json_text] -> String.trim(json_text)
          _ ->
            # Fallback: try to find any JSON object
            case Regex.run(~r/\{.*\}/s, response) do
              [json_text] -> json_text
              _ -> response
            end
        end

      # Try to find any JSON object
      true ->
        case Regex.run(~r/\{.*\}/s, response) do
          [json_text] -> json_text
          _ -> response  # Fallback to full response
        end
    end
  end

  defp get_string_value(data, key) when is_map(data) do
    case data[key] do
      value when is_binary(value) and value != "" -> String.trim(value)
      _ -> nil
    end
  end

  defp get_compensation_entries(nil), do: []
  defp get_compensation_entries(entries) when is_list(entries) do
    entries
    |> Enum.map(&parse_compensation_entry/1)
  end

  defp parse_compensation_entry(entry) when is_map(entry) do
    %{
      amount: parse_compensation(entry["amount"]),
      period: get_string_value(entry, "period"),
      description: get_string_value(entry, "description")
    }
  end
  defp parse_compensation_entry(_), do: %{amount: Decimal.new("0"), period: nil, description: nil}

  defp parse_compensation(nil), do: Decimal.new("0")
  defp parse_compensation(value) when is_number(value), do: Decimal.new(value)
  defp parse_compensation(value) when is_binary(value) do
    # Extract number from string like "$50,000" or "50000"
    cleaned = String.replace(value, ~r/[^0-9.]/, "")
    case Decimal.parse(cleaned) do
      {decimal, _} -> decimal
      :error -> Decimal.new("0")
    end
  end
  defp parse_compensation(_), do: Decimal.new("0")

  defp calculate_final_compensation(data) do
    case data["compensation_entries"] do
      nil ->
        # Fallback to total_compensation if no entries
        case data["total_compensation"] do
          value when is_number(value) -> Decimal.new(value)
          value when is_binary(value) -> parse_compensation(value)
          _ -> Decimal.new("0")
        end
      entries ->
        calculated = calculate_total_compensation(entries)
        # If calculated is zero but total_compensation has a value, use that
        if Decimal.equal?(calculated, Decimal.new("0")) do
          case data["total_compensation"] do
            value when is_number(value) -> Decimal.new(value)
            value when is_binary(value) -> parse_compensation(value)
            _ -> calculated
          end
        else
          calculated
        end
    end
  end

  defp calculate_total_compensation(nil), do: Decimal.new("0")
  defp calculate_total_compensation(entries) when is_list(entries) do
    entries
    |> Enum.map(&calculate_entry_compensation/1)
    |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
  end
  defp calculate_total_compensation(_), do: Decimal.new("0")

  defp calculate_entry_compensation(entry) when is_map(entry) do
    amount = parse_compensation(entry["amount"])
    period = String.downcase(entry["period"] || "")

    case period do
      "monthly" -> Decimal.mult(amount, Decimal.new("12"))
      "annual" -> amount
      "quarterly" -> Decimal.mult(amount, Decimal.new("4"))
      "one-time" -> amount
      _ -> Decimal.new("0")
    end
  end
  defp calculate_entry_compensation(_), do: Decimal.new("0")

  defp parse_date_value(nil), do: nil
  defp parse_date_value(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_date_value(_), do: nil

  # Fallback extraction using document metadata when AI fails
  defp fallback_extraction(metadata) do
    %{
      agent_name: metadata.registrant_name || "Unknown Agent",
      agent_address: nil,
      foreign_principal: metadata.foreign_principal_name || "Unknown Principal",
      country: metadata.foreign_principal_country || "Unknown",
      compensation_entries: [],
      total_compensation: Decimal.new("0"),
      services_description: generate_mock_services(metadata.document_type),
      registration_date: metadata.date_stamped,
      latest_period_start: Date.add(metadata.date_stamped, -90),
      latest_period_end: metadata.date_stamped,
      status: "active"
    }
  end

  defp generate_mock_services(document_type) do
    case document_type do
      "Registration Statement" -> "Government relations and lobbying services"
      "Supplemental Statement" -> "Ongoing government affairs consulting"
      "Informational Materials" -> "Public relations and media services"
      "Exhibit AB" -> "Legal and regulatory consulting"
      _ -> "Foreign agent services"
    end
  end
end
