defmodule NtTask.Repo do
  use Ecto.Repo,
    otp_app: :nt_task,
    adapter: Ecto.Adapters.Postgres
end
