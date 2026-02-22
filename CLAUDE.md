This is a web application written using the Phoenix web framework.

## What This App Does

FARA Tracker is a civic transparency tool that scrapes the U.S. DOJ FARA (Foreign Agent Registration Act) eFiling website, downloads PDF filings, processes them with OpenAI (`gpt-4o-mini`), extracts structured data (agent names, foreign principals, compensation), and presents a dashboard showing foreign agent spending by country.

**Data flow:** CSV from DOJ -> filter document types -> download PDFs -> extract text (`pdftotext` or binary fallback) -> OpenAI extraction -> upsert `fara_registrations` -> LiveView dashboard

## Development Commands

### Essential Commands
- `mix setup` - Install dependencies, create/migrate database, setup assets
- `mix phx.server` - **NEVER RUN** (user manages server separately)
- `mix test` - Run full test suite (includes database setup)
- `mix ecto.reset` - Drop, create, and migrate database with seeds
- `mix assets.build` - Build Tailwind CSS and esbuild assets
- `mix assets.deploy` - Build and minify assets for production

### Database Management
- PostgreSQL on localhost (user/pass: `postgres`/`postgres`)
- Database name: `fara_tracker_dev`
- **NEVER** re-run seeds without explicit permission

### Data Loading Scripts
- `mix run priv/load_data.exs` / `priv/load_full_data.exs` / `priv/simple_load.exs` - Bulk data loading
- `priv/scripts/` - Various scraping/debugging scripts (run with `mix run priv/scripts/<name>.exs`)
- `priv/FARA_All_RegistrantDocs.csv` - Official DOJ CSV export
- **NEVER** run scraping scripts without explicit permission (they hit external APIs and cost money)

### Testing & Quality
- `mix test` - Test suite with automatic database setup
- Test coverage is minimal - mainly controller error tests

## Project Structure

- **App module:** `FaraTracker` / `FaraTrackerWeb`
- **Repo:** `FaraTracker.Repo`
- **Main context:** `FaraTracker.Fara` - all business logic (queries, upserts)
- **Main schema:** `FaraTracker.Fara.Registration` - agent/principal/country/compensation data
- **DB view:** `country_summary` - Postgres view aggregating per-country stats
- **LiveViews:** `DashboardLive` (main dashboard with year tabs), `AboutLive`
- **No authentication** - fully public app, no user accounts
- **No background jobs** - data ingestion is manual via scripts
- **No multi-tenancy** - single-tenant public data

## Data Pipeline

### Scraping (`priv/scripts/scrape_fara.exs`)
The main entry point for data ingestion. Run via `mix run priv/scripts/scrape_fara.exs [options]`.

**CLI flags:**
- `--limit N` (default 5, 0=unlimited) - number of PDFs to process
- `--agent PARTIAL_NAME` - filter by registrant name (case-insensitive substring)
- `--years N` (default 10) - how far back to look
- `--target-year YYYY` - filter to a specific year only

**Pipeline:** reads CSV -> filters by date/type/agent -> downloads PDFs -> extracts text -> sends to OpenAI -> groups by `{agent_name, foreign_principal, country}` -> sums compensation -> upserts to DB.

**Rate limiting:** 300ms sleep between HTTP requests, custom `User-Agent: FARA-Transparency-Tool/1.0 (Public Interest Research)`.

**PDF caching:** Downloaded PDFs are stored in `tmp/fara_downloads/<agent_name>/` and skipped if already present. Safe to re-run without re-downloading.

**Document type filtering:** Only processes substantive types (Exhibit-AB, Registration-Statement, Amendment, Supplemental-Statement, Short-Form). Skips Informational Materials and Dissemination Reports.

### PDF Processing (`FaraTracker.PdfProcessor`)
This is the **active** extraction module. (`FaraTracker.AiExtractor` is a dead stub - ignore it.)

- Uses `pdftotext` system binary (best quality), falls back to Elixir binary stream parser
- Sends extracted text + CSV metadata to OpenAI `gpt-4o-mini` (temperature 0.1)
- If text extraction or OpenAI fails, falls back to metadata-only extraction (compensation = 0)
- Requires `OPENAI_API_KEY` environment variable

### Data Model
- **Upsert key:** `{agent_name, foreign_principal}` - same pair updates existing record, different principal creates new row
- **`country_summary`** is a **Postgres VIEW** (not a table) - defined in migrations, aggregates per-country stats for active registrations
- **`get_country_summary/1`** uses raw SQL with string interpolation for the year filter

### Other Scripts in `priv/scripts/`
- `dedupe_countries.exs` - DB maintenance: normalizes country name variants (has `--dry-run` flag)
- `debug_full_extraction.exs`, `test_*.exs` - One-off diagnostic scripts for debugging PDF/OpenAI extraction on specific files

### Updating Data & Redeploying

Full process to refresh the dashboard with latest FARA filings:

1. **Get fresh CSV** - Download latest `FARA_All_RegistrantDocs.csv` from [fara.gov](https://efile.fara.gov/) and replace `priv/FARA_All_RegistrantDocs.csv`
2. **Run scraper per year** - Process new documents (skips agent/principal pairs already in DB):
   ```bash
   OPENAI_API_KEY=<key> mix run priv/scripts/scrape_fara.exs --target-year 2026 --limit 0
   OPENAI_API_KEY=<key> mix run priv/scripts/scrape_fara.exs --target-year 2025 --limit 0
   ```
3. **Deduplicate countries** - Normalize country name variants:
   ```bash
   mix run priv/scripts/dedupe_countries.exs --dry-run        # review first
   mix run priv/scripts/dedupe_countries.exs --dry-run=false   # apply fixes
   ```
4. **Dump local DB** - Generate SQL backup that ships with the release:
   ```elixir
   mix run -e '
   alias FaraTracker.Repo
   {:ok, result} = Repo.query("COPY fara_registrations TO STDOUT", [])
   header = "COPY public.fara_registrations (id, agent_name, agent_address, foreign_principal, country, registration_date, total_compensation, latest_period_start, latest_period_end, services_description, status, inserted_at, updated_at, document_urls) FROM stdin;\n"
   File.write!("priv/fara_tracker_backup.sql", header <> Enum.join(result.rows, "") <> "\\.\n")
   IO.puts("Wrote #{result.num_rows} rows")
   '
   ```
5. **Deploy** - Build and push to Fly.io:
   ```bash
   fly deploy
   ```
6. **Load data on production** - SSH in and run the Elixir data loader:
   ```bash
   fly ssh console -a fara-tracker -C "/app/bin/fara_tracker eval 'Code.eval_file(\"/app/lib/fara_tracker-0.1.0/priv/load_full_data.exs\")'"
   ```

**Note:** `load_full_data.exs` deletes all existing registrations before importing. The SQL dump is parsed in Elixir because Fly.io's unmanaged Postgres tooling (`psql` proxy, SSH console) is unreliable. See `priv/README.md` for details.

**Note:** If adding a new year, also update the year tabs in `DashboardLive` (`dashboard_live.ex`).

## Project Guidelines

- Use the already included `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`
- OpenAI integration uses `openai_ex` library with `FaraTracker.Finch` connection pool
- PDF text extraction uses `pdftotext` system binary with Elixir binary parser fallback
- Scraping respects rate limits (300ms delay between requests) with public-interest User-Agent header

### Deployment
- **Platform:** Fly.io (app name: `fara-tracker`, region: `iad`)
- **Host:** `fara-tracker.fly.dev`
- Scale-to-zero enabled (`min_machines_running: 0`)
- Release command runs migrations on deploy
- Required env vars: `DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`, `OPENAI_API_KEY`

### JS and CSS Guidelines

- **Tailwind CSS v3** with `tailwind.config.js` (NOT v4)
- Tailwind plugins: `@tailwindcss/forms`, LiveView state variants
- Brand palette defined in `app.css`: teal `#33c1b1`, orange `#F58B00`, dark `#1A2F38`
- Custom CSS classes: `.fara-card-shadow`, `.fara-gradient-bg`, `.fara-agent-row-bg`, `.fara-transition`, `.fara-doc-link`, `.fara-scrollbar`, `.fara-year-tabs`, `.fara-tab-active`
- **Never** use `@apply` when writing raw CSS
- Out of the box **only the app.js and app.css bundles are supported**
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts
  - You must import the vendor deps into app.js and app.css to use them
  - **Never write inline `<script>` tags within templates**

### UI/UX & Design Guidelines

- Dashboard uses mobile-responsive dual layout (desktop table + mobile cards via Tailwind `hidden md:block` / `block md:hidden`)
- MapSet used for O(1) country expand/collapse state tracking
- Year filter tabs (All, 2025, 2024, 2023)
- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- Implement **subtle micro-interactions** (hover effects, smooth transitions)

## Elixir Guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. Use `my_struct.field` or `Ecto.Changeset.get_field/2` for changesets
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure (usually pass `timeout: :infinity`)

## Mix Guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

## Phoenix Guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.
- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias
- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
- **Never** place controller routes (get, post, put, delete) inside `live_session` blocks

## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text` columns
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields

## Phoenix HTML Guidelines

- Phoenix templates **always** use `~H` or .html.heex files (HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` to build forms
- When building forms **always** use `Phoenix.Component.to_form/2` and access via `@form[:field]`
- **Always** add unique DOM IDs to key elements (forms, buttons, etc)
- Elixir does NOT support `if/else if` or `if/elsif` - **always** use `cond` or `case` for multiple conditionals
- HEEx literal curly braces require `phx-no-curly-interpolation` on the parent tag
- HEEx class attrs must use list `[...]` syntax for conditional classes
- **Never** use `<% Enum.each %>` for template content, use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`
- Use `{...}` for attribute interpolation and tag body values; use `<%= ... %>` for block constructs (if, cond, case, for) in tag bodies

#### Map Key Conventions
- Phoenix forms send string keys; internal code uses atom keys
- Never mix keys in the same map
- Use string keys for external data (forms, JSON, CSV), atom keys for internal logic

## Phoenix LiveView Guidelines

- **Never** use deprecated `live_redirect`/`live_patch`, use `<.link navigate={href}>` and `<.link patch={href}>`
- **Avoid LiveComponent's** unless you have a strong, specific need
- LiveViews named like `FaraTrackerWeb.DashboardLive` with `Live` suffix
- `phx-hook="MyHook"` with hook-managed DOM requires `phx-update="ignore"`
- **Never** write embedded `<script>` tags in HEEx
- **Form inputs with `phx-change` MUST be inside a `<form>` tag**

### LiveView Streams

- **Always** use LiveView streams for collections to avoid memory ballooning
- Stream parent element needs `phx-update="stream"` with a DOM id
- Consume `@streams.stream_name` and use the id as DOM id for each child
- Streams are *not* enumerable - to filter/refresh, refetch data and re-stream with `reset: true`
- Track counts via separate assigns; use Tailwind `hidden only:block` for empty states
- **Never** use deprecated `phx-update="append"` or `phx-update="prepend"`

### LiveView Tests

- Use `Phoenix.LiveViewTest` module and `LazyHTML` for assertions
- Form tests use `render_submit/2` and `render_change/2`
- **Always** reference key element IDs in tests
- **Never** test against raw HTML, use `element/2`, `has_element/2`
- Focus on testing outcomes rather than implementation details

### Form Handling

- **Always** use `to_form/2` in the LiveView and `<.input>` component in templates
- **Never** pass a changeset directly to `<.form for={...}>` - always convert with `to_form/2` first
- **Never** use `<.form let={f} ...>` - use `<.form for={@form} ...>` and drive references from `@form[:field]`
- Always give forms an explicit, unique DOM ID
