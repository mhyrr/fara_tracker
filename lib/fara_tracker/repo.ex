defmodule FaraTracker.Repo do
  use Ecto.Repo,
    otp_app: :fara_tracker,
    adapter: Ecto.Adapters.Postgres
end
