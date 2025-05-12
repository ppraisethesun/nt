defmodule NtTask.LLMClient.Behaviour do
  @moduledoc false

  @callback generate_summary(binary(), keyword()) :: {:ok, String.t()} | {:error, any()}
end
