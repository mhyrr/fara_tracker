# FARA Data Loading Process

This directory contains scripts and data files for loading FARA (Foreign Agents Registration Act) data into the application database.

## Files

- `fara_tracker_backup.sql` - PostgreSQL dump containing 796 FARA registration records
- `load_full_data.exs` - Elixir script that parses and loads the complete dataset
- `simple_load.exs` - Test script with sample data (for development/testing)

## Why This Approach?

We're using **Fly.io's unmanaged Postgres**, which has broken/deprecated tooling:
- ❌ `flyctl postgres connect` doesn't work reliably
- ❌ `psql` connections via proxy fail 
- ❌ SSH console hangs on interactive sessions
- ❌ Direct SQL import tools are unusable

## Solution: Custom Elixir Data Parser

Instead of fighting the broken Postgres tooling, we:

1. **Deploy the SQL dump** with the app (in `priv/` directory)
2. **Parse it directly** in Elixir using string manipulation
3. **Use Ecto** (which works) to insert records
4. **Run via non-interactive SSH** to avoid hanging

## Loading Data

### Full Dataset (796 records)
```bash
# Deploy the script
flyctl deploy

# Run the data loader
flyctl ssh console -a fara-tracker -C "/app/bin/fara_tracker eval 'Code.eval_file(\"/app/lib/fara_tracker-0.1.0/priv/load_full_data.exs\")'"
```

### Test Data Only (3 records)
```bash
flyctl ssh console -a fara-tracker -C "/app/bin/fara_tracker eval 'Code.eval_file(\"/app/lib/fara_tracker-0.1.0/priv/simple_load.exs\")'"
```

## How It Works

The `load_full_data.exs` script:

1. **Extracts data** from the PostgreSQL COPY format:
   ```elixir
   data_section = sql_content
   |> String.split("COPY public.fara_registrations")
   |> Enum.at(1)
   |> String.split("\\.")
   |> Enum.at(0)
   |> String.split("\n")
   |> Enum.filter(&String.match?(&1, ~r/^\d+\t/))
   ```

2. **Parses tab-separated values** handling PostgreSQL NULL markers (`\N`)
3. **Converts data types** (dates, decimals) with error handling
4. **Inserts via Ecto** using proper changesets and validation

## Migration Path

When Fly.io managed Postgres becomes available:
1. Contact `beta@fly.io` for access
2. Create new managed database
3. Migrate data using standard PostgreSQL tools
4. Update connection strings
5. Remove these custom scripts

## Data Schema

The script loads data into the `fara_registrations` table with fields:
- `agent_name` - Name of the registered agent/lobbyist
- `agent_address` - Address of the agent
- `foreign_principal` - The foreign entity being represented  
- `country` - Country of the foreign principal
- `registration_date` - When the registration was filed
- `total_compensation` - Total compensation amount
- `latest_period_start/end` - Most recent reporting period
- `services_description` - Description of services provided
- `status` - Registration status (active/inactive)

## Success Metrics

✅ **796 records** successfully imported  
✅ **~$500M** total foreign agent spending tracked  
✅ **Multiple countries** represented  
✅ **Full historical data** preserved ok 