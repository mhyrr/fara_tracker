#!/usr/bin/env elixir

# Debug the full extraction process
pdf_path = "tmp/fara_downloads/Forward_Global_US_Inc./7598-Exhibit-AB-20250526-1.pdf"

# Extract the full text like the real processor does
{text, 0} = System.cmd("pdftotext", [pdf_path, "-"], stderr_to_stdout: true)

IO.puts("Full text length: #{byte_size(text)} bytes")

# Use the same system prompt and extraction process as the real code
system_prompt = """
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

user_prompt = """
Document Type: Exhibit AB
Registrant: Forward Global US, Inc.
Foreign Principal: Taipei Economic and Cultural Representative Office in the United States
Country: TAIWAN
Date Stamped: 2025-05-26

Document Content:
#{text}

Extract the required information as JSON.
"""

case System.get_env("OPENAI_API_KEY") do
  nil ->
    IO.puts("❌ OPENAI_API_KEY not set")

  api_key ->
    openai = OpenaiEx.new(api_key)
            |> OpenaiEx.with_finch_name(FaraTracker.Finch)

    chat_req = OpenaiEx.Chat.Completions.new(
      model: "gpt-4o-mini",
      messages: [
        OpenaiEx.ChatMessage.system(system_prompt),
        OpenaiEx.ChatMessage.user(user_prompt)
      ],
      max_tokens: 2000,
      temperature: 0.1
    )

    case OpenaiEx.Chat.Completions.create(openai, chat_req) do
      {:ok, %{"choices" => [%{"message" => %{"content" => response}} | _]}} ->
        IO.puts("=== RAW OpenAI Response ===")
        IO.puts(response)
        IO.puts("\n" <> String.duplicate("=", 50))

        # Test our JSON extraction logic
        json_text = cond do
          String.contains?(response, "```json") ->
            case Regex.run(~r/```json\s*(\{.*?\})\s*```/s, response) do
              [_, json_text] -> String.trim(json_text)
              _ ->
                case Regex.run(~r/\{.*\}/s, response) do
                  [json_text] -> json_text
                  _ -> response
                end
            end

          true ->
            case Regex.run(~r/\{.*\}/s, response) do
              [json_text] -> json_text
              _ -> response
            end
        end

        IO.puts("\n=== Extracted JSON ===")
        IO.puts(json_text)

        # Try to parse the JSON
        case Jason.decode(json_text) do
          {:ok, data} ->
            IO.puts("\n=== Parsed Data ===")
            IO.inspect(data, pretty: true)

            IO.puts("\n=== Compensation Analysis ===")
            IO.puts("compensation_entries: #{inspect(data["compensation_entries"])}")
            IO.puts("total_compensation: #{inspect(data["total_compensation"])}")
          {:error, reason} ->
            IO.puts("\n❌ JSON Parse Error: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("❌ OpenAI API error: #{inspect(reason)}")

      unexpected ->
        IO.puts("❌ Unexpected response: #{inspect(unexpected)}")
    end
end
