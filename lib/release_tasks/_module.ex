defmodule NtTask.ReleaseTasks do
  @moduledoc false

  def migrate do
    __MODULE__.Migrations.run()
  end
end
