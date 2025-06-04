defmodule FaraTracker.Repo.Migrations.AddDocumentUrlsToRegistrations do
  use Ecto.Migration

  def change do
    alter table(:fara_registrations) do
      add :document_urls, {:array, :text}, default: []
    end
  end
end
