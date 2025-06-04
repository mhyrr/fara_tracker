# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FaraTracker.Repo.insert!(%FaraTracker.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Load data from SQL file if it exists
sql_file = Path.join([Application.app_dir(:fara_tracker, "priv"), "fara_tracker_backup.sql"])

if File.exists?(sql_file) do
  IO.puts("Loading data from SQL file...")

  sql_content = File.read!(sql_file)

  # Execute the SQL directly
  Ecto.Adapters.SQL.query!(FaraTracker.Repo, sql_content)

  IO.puts("Data loaded successfully!")
else
  IO.puts("No SQL file found at #{sql_file}")
end
