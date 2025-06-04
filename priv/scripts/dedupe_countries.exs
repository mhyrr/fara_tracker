#!/usr/bin/env elixir

# Country Deduplication Script for FARA Registrations
# Run with: mix run priv/scripts/dedupe_countries.exs

defmodule CountryDeduper do
  @moduledoc """
  Fixes country name inconsistencies in FARA registrations.

  Issues:
  - Mixed capitalization: "RUSSIA" vs "Russia" vs "russia"
  - Inconsistent formatting: "United States" vs "USA" vs "US"
  - Whitespace issues: "Canada " vs "Canada"

  Strategy:
  1. Find all unique country values
  2. Group by normalized version (downcased, trimmed)
  3. Pick canonical form (most common or best formatted)
  4. Update all records to use canonical form
  """

  require Logger
  alias FaraTracker.Repo
  alias FaraTracker.Fara.Registration
  import Ecto.Query

  def run(opts \\ []) do
    Logger.info("🔄 Starting country deduplication...")

    dry_run = Keyword.get(opts, :dry_run, true)

    if dry_run do
      Logger.info("🔍 DRY RUN - No changes will be made")
    else
      Logger.info("⚠️  LIVE RUN - Database will be modified")
    end

    # Step 1: Analyze current country data
    country_groups = analyze_countries()

    # Step 2: Find duplicates
    duplicates = find_duplicates(country_groups)

    # Step 3: Show what we found
    show_analysis(country_groups, duplicates)

    # Step 4: Fix duplicates
    if length(duplicates) > 0 do
      fix_duplicates(duplicates, dry_run)
    else
      Logger.info("✅ No duplicates found!")
    end

    Logger.info("🏁 Deduplication complete")
  end

  defp analyze_countries do
    query = from r in Registration,
            group_by: r.country,
            select: {r.country, count(r.id)},
            order_by: [desc: count(r.id)]

    Repo.all(query)
    |> Enum.map(fn {country, count} ->
      %{
        original: country,
        normalized: normalize_country(country),
        count: count
      }
    end)
    |> Enum.group_by(& &1.normalized)
  end

  defp find_duplicates(country_groups) do
    country_groups
    |> Enum.filter(fn {_normalized, variants} -> length(variants) > 1 end)
    |> Enum.map(fn {normalized, variants} ->
      # Pick canonical form - prefer proper case over all caps/lowercase
      canonical = pick_canonical(variants)

      %{
        normalized: normalized,
        canonical: canonical.original,
        variants: variants,
        total_records: Enum.sum(Enum.map(variants, & &1.count))
      }
    end)
  end

  defp pick_canonical(variants) do
    # Prefer:
    # 1. Most common variant
    # 2. Proper case over ALL CAPS or lowercase
    # 3. Longest version (more descriptive)

    variants
    |> Enum.sort_by(fn variant ->
      {
        -variant.count,  # Most common first
        -score_formatting(variant.original),  # Better formatting first
        -String.length(variant.original)  # Longer first
      }
    end)
    |> List.first()
  end

  defp score_formatting(country) do
    cond do
      # Proper case (first letter caps, rest mixed)
      String.match?(country, ~r/^[A-Z][a-z]/) -> 3

      # Title case (multiple words capitalized)
      String.match?(country, ~r/^[A-Z][a-z].*\s[A-Z][a-z]/) -> 2

      # All lowercase
      String.match?(country, ~r/^[a-z]/) -> 1

      # ALL CAPS or mixed - lowest priority
      true -> 0
    end
  end

  defp normalize_country(country) when is_binary(country) do
    country
    |> String.trim()
    |> String.downcase()
    |> standardize_country_name()
  end
  defp normalize_country(nil), do: "unknown"

  # Standardize common country name variations
  defp standardize_country_name(country) do
    case country do
      # US variations
      name when name in ["usa", "united states", "united states of america", "u.s.", "u.s.a."] ->
        "united states"

      # UK variations
      name when name in ["uk", "united kingdom", "great britain", "britain", "england"] ->
        "united kingdom"

      # Russia variations
      name when name in ["russia", "russian federation"] ->
        "russia"

      # China variations
      name when name in ["china", "people's republic of china", "prc"] ->
        "china"

      # Keep as-is for everything else
      name -> name
    end
  end

  defp show_analysis(country_groups, duplicates) do
    total_countries = map_size(country_groups)
    unique_countries = country_groups |> Map.values() |> List.flatten() |> length()

    Logger.info("📊 Country Analysis:")
    Logger.info("   Total unique country values: #{unique_countries}")
    Logger.info("   Normalized country count: #{total_countries}")
    Logger.info("   Duplicate groups: #{length(duplicates)}")

    if length(duplicates) > 0 do
      Logger.info("\n🔍 Found duplicates:")

      Enum.each(duplicates, fn dup ->
        Logger.info("   #{dup.canonical} (#{dup.total_records} total records):")

        Enum.each(dup.variants, fn variant ->
          status = if variant.original == dup.canonical, do: "✓ CANONICAL", else: "→ merge"
          Logger.info("     #{variant.original} (#{variant.count} records) #{status}")
        end)

        Logger.info("")
      end)
    end
  end

  defp fix_duplicates(duplicates, dry_run) do
    Logger.info("🔧 Fixing #{length(duplicates)} duplicate groups...")

    Enum.each(duplicates, fn dup ->
      # Update all non-canonical variants
      variants_to_update = Enum.reject(dup.variants, & &1.original == dup.canonical)

      Enum.each(variants_to_update, fn variant ->
        update_count = if dry_run do
          # Just count what would be updated
          from(r in Registration, where: r.country == ^variant.original)
          |> Repo.aggregate(:count, :id)
        else
          # Actually update
          from(r in Registration, where: r.country == ^variant.original)
          |> Repo.update_all(set: [country: dup.canonical, updated_at: DateTime.utc_now()])
          |> elem(0)  # Get count from {count, nil} tuple
        end

        action = if dry_run, do: "Would update", else: "Updated"
        Logger.info("   #{action} #{update_count} records: '#{variant.original}' → '#{dup.canonical}'")
      end)
    end)

    unless dry_run do
      Logger.info("✅ Database updated successfully!")
      Logger.info("💡 Tip: Run the dashboard to verify changes")
    end
  end
end

# Parse command line arguments
{opts, _} = System.argv() |> OptionParser.parse!(
  switches: [
    dry_run: :boolean,
    help: :boolean
  ],
  aliases: [
    d: :dry_run,
    h: :help
  ]
)

if opts[:help] do
  IO.puts """
  Country Deduplication Script

  Usage: mix run priv/scripts/dedupe_countries.exs [options]

  Options:
    --dry-run, -d    Show what would be changed without modifying database (default: true)
    --help, -h       Show this help

  Examples:
    mix run priv/scripts/dedupe_countries.exs                    # Dry run
    mix run priv/scripts/dedupe_countries.exs --dry-run=false    # Actually fix duplicates
  """
else
  CountryDeduper.run(opts)
end
