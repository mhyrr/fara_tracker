# FARA Tracker

A Phoenix LiveView application for tracking foreign agent registrations under the Foreign Agent Registration Act (FARA). This tool aggregates and analyzes foreign influence spending by country with document scraping capabilities.

## 🎯 Features

- **Dashboard**: Real-time view of foreign influence spending by country
- **Document Scraper**: Automated PDF collection from FARA database
- **Smart Filtering**: Focus on substantive documents (excludes marketing materials)
- **Database**: PostgreSQL with optimized schema for FARA data

## 🏗️ Architecture

- **Backend**: Elixir/Phoenix with Ecto
- **Frontend**: Phoenix LiveView with Tailwind CSS
- **Database**: PostgreSQL with aggregation views
- **HTTP Client**: Req for document downloads
- **CSV Processing**: NimbleCSV for data parsing

## 📊 Document Types Processed

**✅ Substantive Documents:**
- Supplemental Statements (semi-annual activity reports)
- Exhibit AB (compensation agreements)
- Short Forms (brief activity filings)
- Amendments (registration changes)
- Registration Statements (initial filings)

**❌ Filtered Out:**
- Informational Materials (marketing/PR content)
- Dissemination Reports (publication tracking)

## 🚀 Quick Start

### Prerequisites
- Elixir 1.18+ and Phoenix
- PostgreSQL
- FARA document CSV file (place in `priv/`)

### Setup
```bash
# Install dependencies
mix deps.get

# Setup database
mix ecto.create
mix ecto.migrate

# Start server
mix phx.server
```

Visit [http://localhost:4000](http://localhost:4000) to see the dashboard.

### Document Scraping
```bash
# Basic scraping (5 documents, last 10 years)
mix run priv/scripts/scrape_fara.exs

# Filter by agent/firm
mix run priv/scripts/scrape_fara.exs --agent "Brownstein" --limit 3

# Longer time range
mix run priv/scripts/scrape_fara.exs --limit 10 --years 15

# Help
mix run priv/scripts/scrape_fara.exs --help
```

## 📁 Database Schema

```sql
-- Main registrations table
CREATE TABLE fara_registrations (
  id SERIAL PRIMARY KEY,
  agent_name VARCHAR(255) NOT NULL,
  foreign_principal VARCHAR(255) NOT NULL,
  country VARCHAR(100) NOT NULL,
  total_compensation DECIMAL(12,2) DEFAULT 0,
  registration_date DATE,
  services_description TEXT,
  status VARCHAR(50) DEFAULT 'active',
  -- ... timestamps
);

-- Aggregation view for dashboard
CREATE VIEW country_summary AS
SELECT 
  country,
  COUNT(*) as agent_count,
  SUM(total_compensation) as total_spending
FROM fara_registrations 
WHERE status = 'active'
GROUP BY country
ORDER BY total_spending DESC;
```

## 📄 Downloaded Documents

PDFs are organized by registrant:
```
tmp/fara_downloads/
├── Brownstein_Hyatt_Farber_Schreck_LLP/
│   ├── 1234-Supplemental-Statement-20241201-12.pdf
│   └── 1234-Exhibit-AB-20241115-3.pdf
├── Akin_Gump_Strauss_Hauer_Feld_LLP/
│   └── 5678-Amendment-20241210-8.pdf
└── ...
```

## 🔮 Future Enhancements

- [ ] OpenAI integration for PDF data extraction
- [ ] Advanced search and filtering
- [ ] Trend analysis and visualizations
- [ ] Export capabilities
- [ ] Real-time FARA website monitoring

## 📚 Data Sources

- **FARA eFiling Database**: Official DOJ foreign agent registrations
- **CSV Export**: Complete document registry with direct PDF URLs
- **Document Types**: Comprehensive collection of FARA filings

## 🛠️ Development

Built as a weekend project to demonstrate:
- Phoenix LiveView real-time capabilities
- Document processing pipelines
- Data aggregation and visualization
- Clean separation of concerns

## 📄 License

MIT License - See LICENSE file for details.
