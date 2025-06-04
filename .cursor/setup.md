# FARA Tracker Development Setup

## Environment
- **OS**: macOS (darwin 24.5.0)
- **Shell**: /bin/zsh
- **Elixir**: 1.18.3
- **OTP**: 27
- **Phoenix**: Latest
- **Database**: PostgreSQL running in Docker Desktop

## Database Configuration
- **Host**: localhost
- **Port**: 5432 (default)
- **Database**: fara_tracker_dev
- **Username**: postgres
- **Password**: postgres
- **Status**: ✅ Running in Docker Desktop

## ✅ RESOLVED - Database Connection Issue

### The Problem
Phoenix was connecting to a **local PostgreSQL@14 server** instead of the **Docker PostgreSQL container**. Both were running on port 5432, causing a conflict:

- **Local PostgreSQL**: Empty `fara_tracker_dev` database (0 records)
- **Docker PostgreSQL**: Populated `fara_tracker_dev` database (796 records)

### The Solution  
```bash
# Stop the local PostgreSQL service
brew services stop postgresql@14
```

This allows Phoenix to connect to the Docker database where all the FARA data actually exists.

## Current State ✅

### Database Connection
- ✅ Phoenix connects to Docker PostgreSQL (`arete-postgres-1`)
- ✅ Database contains 796 FARA registration records
- ✅ All records have `status = 'active'`
- ✅ Dashboard query should now work correctly

### Application Status
- ✅ Phoenix server runs successfully on localhost:4000
- ✅ Database connection works (Docker)
- ✅ LiveView dashboard loads
- ✅ Data is available (796 records)
- ✅ Query structure is correct
- ✅ UI/UX is functional

## Development Commands
```bash
# Start the server
mix phx.server

# Database operations (connects to Docker)
mix ecto.create
mix ecto.migrate
mix ecto.seed  # May need to implement this

# Connect to Docker database directly
docker exec -it arete-postgres-1 psql -U postgres -d fara_tracker_dev

# Check current data
mix run -e 'result = FaraTracker.Repo.query!("SELECT COUNT(*) FROM fara_registrations"); IO.inspect(result)'
```

## Docker PostgreSQL Container
- **Container**: `arete-postgres-1`
- **Port Mapping**: `0.0.0.0:5432->5432/tcp`
- **Databases**: `arete_dev`, `arete_test`, `fara_tracker_dev`, `postgres`
- **Data**: 796 FARA registration records in `fara_tracker_dev`

## Troubleshooting

### If dashboard shows no data:
1. **Check local PostgreSQL**: `ps aux | grep postgres`
2. **Stop local PostgreSQL**: `brew services stop postgresql@14`
3. **Verify Docker connection**: `docker ps | grep postgres`
4. **Test record count**: `mix run -e 'FaraTracker.Repo.query!("SELECT COUNT(*) FROM fara_registrations") |> IO.inspect'`

### Port conflicts:
- Local PostgreSQL (if running) conflicts with Docker on port 5432
- Always ensure local PostgreSQL is stopped for development
- Docker container must be running: `docker start arete-postgres-1`

## File Locations
- Main app: `/Users/mhyrr/work/fara_tracker`
- Database backups: `fara_tracker_backup.sql`, `local_fara_dump.sql`
- Downloaded data: `tmp/fara_downloads/`
- Config: `config/dev.exs`
- Seeds: `priv/repo/seeds.exs`

## Next Steps
✅ **RESOLVED** - Dashboard should now display FARA data correctly at http://localhost:4000 