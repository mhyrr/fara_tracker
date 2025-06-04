#!/usr/bin/env elixir

# Direct test of OpenAI compensation extraction
test_text = """
Contractor will be paid a sum of $50,000 a month for Services performed.

As necessary, a budget for additional program elements, including travel costs, video
production, and digital advertising, would be agreed to by the Parties, and invoiced
separately.

Compensation. Client shall pay Contractor for the Services performed in the
amounts of compensation in Exhibit 2, attached hereto and incorporated herein ("Payment").
"""

prompt = """
Extract compensation information from this text. Look for dollar amounts and time periods.

Text: #{test_text}

Return JSON with this format:
{
  "compensation_entries": [
    {
      "amount": "number - the dollar amount (no $ sign)",
      "period": "string - annual/monthly/quarterly/one-time",
      "description": "string - description of the compensation"
    }
  ],
  "total_compensation": "number - total annual compensation (convert all entries to yearly and sum)"
}
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
        OpenaiEx.ChatMessage.user(prompt)
      ],
      max_tokens: 500,
      temperature: 0.1
    )

    case OpenaiEx.Chat.Completions.create(openai, chat_req) do
      {:ok, %{"choices" => [%{"message" => %{"content" => response}} | _]}} ->
        IO.puts("=== OpenAI Response ===")
        IO.puts(response)

        # Try to parse the JSON
        case Jason.decode(response) do
          {:ok, data} ->
            IO.puts("\n=== Parsed Data ===")
            IO.inspect(data, pretty: true)
          {:error, reason} ->
            IO.puts("\n❌ JSON Parse Error: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("❌ OpenAI API error: #{inspect(reason)}")

      unexpected ->
        IO.puts("❌ Unexpected response: #{inspect(unexpected)}")
    end
end
