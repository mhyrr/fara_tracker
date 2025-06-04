#!/usr/bin/env elixir

# Test compensation extraction
pdf_path = "tmp/fara_downloads/Forward_Global_US_Inc./7598-Exhibit-AB-20250526-1.pdf"

# Test pdftotext extraction
case System.cmd("pdftotext", [pdf_path, "-"], stderr_to_stdout: true) do
  {text, 0} ->
    IO.puts("=== TEXT ANALYSIS ===")
    IO.puts("Full text length: #{byte_size(text)} bytes")

    # Find where the compensation line appears
    compensation_line = "Contractor will be paid a sum of $50,000 a month for Services performed."
    case :binary.match(text, compensation_line) do
      {start_pos, _length} ->
        IO.puts("Compensation line found at position: #{start_pos}")
        IO.puts("Is within 20KB limit? #{start_pos < 20000}")
      :nomatch ->
        IO.puts("Compensation line not found (unexpected!)")
    end

    # Show what gets sent to OpenAI (first 20KB)
    truncated_text = String.slice(text, 0, 20000)
    IO.puts("Truncated text length: #{byte_size(truncated_text)} bytes")

    if String.contains?(truncated_text, "50,000") do
      IO.puts("✅ '50,000' survives truncation")
    else
      IO.puts("❌ '50,000' lost in truncation")
    end

    if String.contains?(truncated_text, compensation_line) do
      IO.puts("✅ Full compensation line survives truncation")
    else
      IO.puts("❌ Full compensation line lost in truncation")
    end

    IO.puts("\n=== COMPENSATION-RELATED LINES IN TRUNCATED TEXT ===")
    lines = String.split(truncated_text, "\n")
    compensation_lines = Enum.filter(lines, fn line ->
      String.contains?(String.downcase(line), "50,000") or
      (String.contains?(String.downcase(line), "paid") and String.contains?(String.downcase(line), "month"))
    end)

    Enum.each(compensation_lines, fn line ->
      IO.puts(">>> #{line}")
    end)

  {error, _} ->
    IO.puts("Error: #{error}")
end
