# Full FARA data loader
IO.puts("Starting full data load...")

# Make sure app is started
Application.ensure_all_started(:fara_tracker)

alias FaraTracker.Repo
alias FaraTracker.Fara.Registration

# First clear existing test data
IO.puts("Clearing existing test data...")
Repo.delete_all(Registration)

# Read and parse the SQL dump
sql_file = Path.join([__DIR__, "fara_tracker_backup.sql"])

if File.exists?(sql_file) do
  IO.puts("Reading SQL dump file...")

  sql_content = File.read!(sql_file)

  # Extract just the data lines between COPY and \.
  data_section = sql_content
  |> String.split("COPY public.fara_registrations")
  |> Enum.at(1)
  |> String.split("\\.")
  |> Enum.at(0)
  |> String.split("\n")
  |> Enum.filter(&String.match?(&1, ~r/^\d+\t/))

  IO.puts("Found #{length(data_section)} records to process...")

  successful_imports = 0
  failed_imports = 0

  for {line, index} <- Enum.with_index(data_section, 1) do
    try do
      # Split the tab-separated values
      parts = String.split(line, "\t")

      if length(parts) >= 14 do
        # Parse the fields according to the COPY statement columns
        [_id, agent_name, agent_address, foreign_principal, country, registration_date,
         total_compensation, latest_period_start, latest_period_end, services_description,
         status, _inserted_at, _updated_at, document_urls | _rest] = parts

        # Parse dates (handle NULL values)
        parse_date = fn
          "\\N" -> nil
          date_str ->
            try do
              Date.from_iso8601!(date_str)
            rescue
              _ -> nil
            end
        end

        # Parse decimal (handle NULL values)
        parse_decimal = fn
          "\\N" -> Decimal.new("0.00")
          "" -> Decimal.new("0.00")
          dec_str ->
            try do
              Decimal.new(dec_str)
            rescue
              _ -> Decimal.new("0.00")
            end
        end

        # Parse PostgreSQL array format {url1,url2} -> ["url1", "url2"]
        parse_document_urls = fn
          "\\N" -> []
          "" -> []
          urls_str ->
            try do
              # Remove curly braces and split by comma
              urls_str
              |> String.trim_leading("{")
              |> String.trim_trailing("}")
              |> String.split(",")
              |> Enum.map(&String.trim/1)
              |> Enum.reject(&(&1 == ""))
            rescue
              _ -> []
            end
        end

        # Clean up NULL values
        clean_field = fn
          "\\N" -> nil
          field -> field
        end

        # Create the registration
        attrs = %{
          agent_name: clean_field.(agent_name),
          agent_address: clean_field.(agent_address),
          foreign_principal: clean_field.(foreign_principal),
          country: clean_field.(country),
          registration_date: parse_date.(registration_date),
          total_compensation: parse_decimal.(total_compensation),
          latest_period_start: parse_date.(latest_period_start),
          latest_period_end: parse_date.(latest_period_end),
          services_description: clean_field.(services_description),
          status: clean_field.(status) || "active",
          document_urls: parse_document_urls.(document_urls)
        }

        case Repo.insert(%Registration{
          agent_name: attrs.agent_name,
          agent_address: attrs.agent_address,
          foreign_principal: attrs.foreign_principal,
          country: attrs.country,
          registration_date: attrs.registration_date,
          total_compensation: attrs.total_compensation,
          latest_period_start: attrs.latest_period_start,
          latest_period_end: attrs.latest_period_end,
          services_description: attrs.services_description,
          status: attrs.status,
          document_urls: attrs.document_urls
        }) do
          {:ok, _registration} ->
            successful_imports = successful_imports + 1
            if rem(index, 100) == 0 do
              IO.puts("Processed #{index} records...")
            end
          {:error, changeset} ->
            failed_imports = failed_imports + 1
            IO.puts("Failed to insert record #{index}: #{inspect(changeset.errors)}")
        end
      else
        IO.puts("Skipping malformed line #{index}: insufficient fields")
        failed_imports = failed_imports + 1
      end
    rescue
      error ->
        IO.puts("Error processing line #{index}: #{inspect(error)}")
        failed_imports = failed_imports + 1
    end
  end

  final_count = Repo.aggregate(Registration, :count, :id)
  IO.puts("\n=== Import Complete ===")
  IO.puts("Successfully imported: #{successful_imports}")
  IO.puts("Failed imports: #{failed_imports}")
  IO.puts("Total records in database: #{final_count}")

else
  IO.puts("SQL file not found at #{sql_file}")
end
