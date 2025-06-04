# Simple script to load FARA data
alias FaraTracker.Repo

# Read the SQL file
sql_file = Path.join([__DIR__, "fara_tracker_backup.sql"])

if File.exists?(sql_file) do
  IO.puts("Loading data from SQL file...")

  sql_content = File.read!(sql_file)

  # Split by COPY statements to avoid the huge data block
  parts = String.split(sql_content, "COPY")

  # Execute the schema creation parts first
  schema_parts = parts |> Enum.take(2)

  for part <- schema_parts do
    if String.trim(part) != "" do
      try do
        # Add COPY back if needed
        sql = if String.contains?(part, "fara_registrations") do
          "COPY" <> part
        else
          part
        end

        # Skip the large data insert for now
        unless String.contains?(sql, "1\t") do
          IO.puts("Executing: #{String.slice(sql, 0, 100)}...")
          Ecto.Adapters.SQL.query!(Repo, sql)
        end
      rescue
        error ->
          IO.puts("Error with part: #{error}")
      end
    end
  end

  IO.puts("Schema created! Now let's load a few sample records...")

  # Just insert a few sample records manually to test
  sample_data = [
    %{
      agent_name: "Test Registrant",
      agent_address: "123 Test St",
      foreign_principal: "Test Country",
      country: "TEST",
      registration_date: ~D[2023-01-01],
      total_compensation: Decimal.new("100000.00"),
      latest_period_end: ~D[2023-12-31],
      services_description: "Testing purposes",
      status: "active"
    }
  ]

  for data <- sample_data do
    Repo.insert!(%FaraTracker.Fara.Registration{
      agent_name: data.agent_name,
      agent_address: data.agent_address,
      foreign_principal: data.foreign_principal,
      country: data.country,
      registration_date: data.registration_date,
      total_compensation: data.total_compensation,
      latest_period_end: data.latest_period_end,
      services_description: data.services_description,
      status: data.status
    })
  end

  IO.puts("Sample data loaded successfully!")
else
  IO.puts("No SQL file found at #{sql_file}")
end
