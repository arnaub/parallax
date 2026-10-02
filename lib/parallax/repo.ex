defmodule Parallax.Repo do
  use Ecto.Repo,
    otp_app: :parallax,
    adapter: Ecto.Adapters.Postgres
end
