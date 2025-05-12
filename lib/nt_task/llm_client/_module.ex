defmodule NtTask.LLMClient do
  @moduledoc false

  @adapter Application.compile_env(:nt_task, :llm_adapter, NtTask.LLMClient.OpenAIAdapter)

  @spec generate_summary(binary(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def generate_summary(pdf_content, opts \\ []) when is_binary(pdf_content) do
    @adapter.generate_summary(pdf_content, opts)
  end
end
