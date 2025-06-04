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

    # Step 3: Find ALL CAPS countries that need fixing
    all_caps_countries = find_all_caps_countries(country_groups)

    # Step 4: Show what we found
    show_analysis(country_groups, duplicates, all_caps_countries)

    # Step 5: Fix duplicates
    if length(duplicates) > 0 do
      fix_duplicates(duplicates, dry_run)
    else
      Logger.info("✅ No duplicates found!")
    end

    # Step 6: Fix ALL CAPS countries
    if length(all_caps_countries) > 0 do
      fix_all_caps_countries(all_caps_countries, dry_run)
    else
      Logger.info("✅ No ALL CAPS countries found!")
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
    # Manual overrides for specific cases where we want a particular canonical form
    canonical_overrides = %{
      "south korea" => "South Korea",
      "north korea" => "North Korea",
      "democratic republic of the congo" => "Democratic Republic of the Congo",
      "republic of the congo" => "Republic of the Congo",
      "côte d'ivoire" => "Côte d'Ivoire"
    }

    normalized = variants |> List.first() |> Map.get(:normalized)

    case Map.get(canonical_overrides, normalized) do
      nil ->
        # No override, use normal logic but with capitalization preference
        canonical = variants
        |> Enum.sort_by(fn variant ->
          {
            -variant.count,  # Most common first
            -score_formatting(variant.original),  # Better formatting first
            -String.length(variant.original)  # Longer first
          }
        end)
        |> List.first()

        # If the canonical is ALL CAPS, convert to proper case
        proper_name = if is_all_caps?(canonical.original) do
          to_proper_case(canonical.original)
        else
          canonical.original
        end

        %{canonical | original: proper_name}

      override_name ->
        # Use override, but make sure it exists in variants
        case Enum.find(variants, fn v -> v.original == override_name end) do
          nil ->
            # Override doesn't exist, fall back to normal logic but update original
            canonical = variants
            |> Enum.sort_by(fn variant ->
              {
                -variant.count,
                -score_formatting(variant.original),
                -String.length(variant.original)
              }
            end)
            |> List.first()

            %{canonical | original: override_name}

          found ->
            found
        end
    end
  end

  defp is_all_caps?(country) do
    String.match?(country, ~r/^[A-Z][A-Z\s,\.]+$/) && String.length(country) > 2
  end

  defp to_proper_case(country) do
    # Handle special cases that shouldn't be title-cased
    special_words = %{
      "and" => "and",
      "of" => "of",
      "the" => "the",
      "da" => "da",
      "de" => "de",
      "del" => "del",
      "la" => "la",
      "le" => "le",
      "van" => "van",
      "von" => "von"
    }

    # Geographic/political terms that should stay uppercase
    uppercase_words = %{
      "uk" => "UK",
      "usa" => "USA",
      "uae" => "UAE",
      "arab" => "Arab",  # In context like "United Arab Emirates"
      "kong" => "Kong",  # In context like "Hong Kong"
      "st" => "St.",     # Saint abbreviation
      "st." => "St."
    }

    country
    |> String.split()
    |> Enum.with_index()
    |> Enum.map(fn {word, index} ->
      lowered = String.downcase(word)

      cond do
        # Check for special uppercase words first
        Map.has_key?(uppercase_words, lowered) ->
          uppercase_words[lowered]

        # First word is always capitalized
        index == 0 ->
          String.capitalize(word)

        # Check for special words that should stay lowercase
        Map.has_key?(special_words, lowered) ->
          special_words[lowered]

        # Regular word - capitalize first letter
        true ->
          String.capitalize(word)
      end
    end)
    |> Enum.join(" ")
  end

  defp score_formatting(country) do
    cond do
      # Proper case (first letter caps, rest mixed)
      String.match?(country, ~r/^[A-Z][a-z]/) -> 4

      # Title case (multiple words capitalized properly)
      String.match?(country, ~r/^[A-Z][a-z].*\s[A-Z][a-z]/) -> 3

      # All lowercase
      String.match?(country, ~r/^[a-z]/) -> 2

      # ALL CAPS - lowest priority (we want to convert these)
      is_all_caps?(country) -> 0

      # Mixed or other - middle priority
      true -> 1
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

      # South Korea variations
      name when name in ["korea south", "korea, south", "south korea", "republic of korea"] ->
        "south korea"

      # North Korea variations
      name when name in ["korea north", "korea, north", "north korea", "democratic people's republic of korea", "dprk"] ->
        "north korea"

      # Democratic Republic of Congo variations
      name when name in [
        "democratic republic of congo",
        "congo democratic republic",
        "congo democratic republic of the",
        "congo, democratic republic of the",
        "democratic republic of the congo",
        "drc"
      ] ->
        "democratic republic of the congo"

      # Republic of Congo variations
      name when name in [
        "congo republic",
        "congo, republic of the",
        "republic of congo",
        "republic of the congo"
      ] ->
        "republic of the congo"

      # Taiwan variations
      name when name in ["taiwan", "republic of china", "chinese taipei"] ->
        "taiwan"

      # Myanmar variations
      name when name in ["myanmar", "burma"] ->
        "myanmar"

      # Czech Republic variations
      name when name in ["czech republic", "czechia"] ->
        "czech republic"

      # Macedonia variations
      name when name in ["macedonia", "north macedonia", "former yugoslav republic of macedonia", "fyrom"] ->
        "north macedonia"

      # Bosnia variations
      name when name in ["bosnia", "bosnia and herzegovina", "bosnia-herzegovina"] ->
        "bosnia and herzegovina"

      # Vatican variations
      name when name in ["vatican", "vatican city", "holy see"] ->
        "vatican city"

      # Ivory Coast variations
      name when name in ["ivory coast", "cote d'ivoire", "côte d'ivoire", "cote d'ivoire ivory coast"] ->
        "côte d'ivoire"

      # Keep as-is for everything else
      name -> name
    end
  end

  defp show_analysis(country_groups, duplicates, all_caps_countries) do
    total_countries = map_size(country_groups)
    unique_countries = country_groups |> Map.values() |> List.flatten() |> length()

    Logger.info("📊 Country Analysis:")
    Logger.info("   Total unique country values: #{unique_countries}")
    Logger.info("   Normalized country count: #{total_countries}")
    Logger.info("   Duplicate groups: #{length(duplicates)}")
    Logger.info("   ALL CAPS countries: #{length(all_caps_countries)}")

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

    if length(all_caps_countries) > 0 do
      Logger.info("\n🔍 Found ALL CAPS countries:")

      Enum.each(all_caps_countries, fn country ->
        Logger.info("   #{country.original} (#{country.count} records)")
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

  defp find_all_caps_countries(country_groups) do
    country_groups
    |> Enum.filter(fn {_normalized, variants} ->
      Enum.all?(variants, fn variant -> is_all_caps?(variant.original) end)
    end)
    |> Enum.flat_map(fn {_normalized, variants} ->
      Enum.map(variants, fn variant ->
        %{
          original: variant.original,
          normalized: variant.normalized,
          count: variant.count
        }
      end)
    end)
  end

  defp fix_all_caps_countries(all_caps_countries, dry_run) do
    Logger.info("🔧 Fixing #{length(all_caps_countries)} ALL CAPS countries...")

    Enum.each(all_caps_countries, fn country ->
      proper_name = to_proper_case(country.original)

      update_count = if dry_run do
        # Just count what would be updated
        from(r in Registration, where: r.country == ^country.original)
        |> Repo.aggregate(:count, :id)
      else
        # Actually update
        from(r in Registration, where: r.country == ^country.original)
        |> Repo.update_all(set: [country: proper_name, updated_at: DateTime.utc_now()])
        |> elem(0)  # Get count from {count, nil} tuple
      end

      action = if dry_run, do: "Would update", else: "Updated"
      Logger.info("   #{action} #{update_count} records: '#{country.original}' → '#{proper_name}'")
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
