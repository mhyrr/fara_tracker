# Simple data loader
IO.puts("Starting data load...")

# Make sure app is started
Application.ensure_all_started(:fara_tracker)

alias FaraTracker.Repo
alias FaraTracker.Fara.Registration

# Sample data from the FARA dump
sample_registrations = [
  %{
    agent_name: "Arnold & Porter Kaye Scholer LLP",
    agent_address: "601 Massachusetts Ave., NW, Washington, DC 20001",
    foreign_principal: "Government of the Federated States of Micronesia",
    country: "MICRONESIA",
    registration_date: ~D[2023-10-18],
    total_compensation: Decimal.new("1812000.00"),
    latest_period_start: ~D[2023-10-18],
    latest_period_end: ~D[2024-10-17],
    services_description: "Providing legal and advisory services to the Foreign Principal, including advice on legal and administrative issues arising from the Compact of Free Association between the Federated States of Micronesia and the United States.",
    status: "active"
  },
  %{
    agent_name: "BGR Government Affairs, LLC",
    agent_address: "601 Thirteenth Street, NW, Eleventh Floor South, Washington, DC 20005",
    foreign_principal: "Bahaa Hariri",
    country: "LEBANON",
    registration_date: ~D[2023-03-01],
    total_compensation: Decimal.new("200000.00"),
    latest_period_start: ~D[2023-03-01],
    latest_period_end: ~D[2023-05-31],
    services_description: "Provide government relations services",
    status: "active"
  },
  %{
    agent_name: "Teneo Strategy LLC",
    agent_address: "280 Park Avenue, 4th Floor, New York, NY 10017",
    foreign_principal: "Public Investment Fund",
    country: "SAUDI ARABIA",
    registration_date: ~D[2023-01-01],
    total_compensation: Decimal.new("8610000.00"),
    latest_period_start: ~D[2023-01-01],
    latest_period_end: ~D[2023-12-31],
    services_description: "International communications and stakeholder engagement plan to position PIF as a sophisticated global investment organization.",
    status: "active"
  }
]

IO.puts("Inserting #{length(sample_registrations)} sample registrations...")

for reg_data <- sample_registrations do
  case Repo.insert(%Registration{
    agent_name: reg_data.agent_name,
    agent_address: reg_data.agent_address,
    foreign_principal: reg_data.foreign_principal,
    country: reg_data.country,
    registration_date: reg_data.registration_date,
    total_compensation: reg_data.total_compensation,
    latest_period_start: reg_data.latest_period_start,
    latest_period_end: reg_data.latest_period_end,
    services_description: reg_data.services_description,
    status: reg_data.status
  }) do
    {:ok, registration} ->
      IO.puts("✓ Inserted: #{registration.agent_name}")
    {:error, changeset} ->
      IO.puts("✗ Failed to insert: #{inspect(changeset.errors)}")
  end
end

count = Repo.aggregate(Registration, :count, :id)
IO.puts("Total registrations in database: #{count}")
IO.puts("Data load complete!")
