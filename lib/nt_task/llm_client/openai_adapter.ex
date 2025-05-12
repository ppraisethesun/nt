defmodule NtTask.LLMClient.OpenAIAdapter do
  @behaviour NtTask.LLMClient.Behaviour

  @model "gpt-4o-mini"
  @response_format %{
    type: "json_schema",
    json_schema: %{
      name: "summary",
      description: "A summary of the document",
      strict: true,
      schema: %{
        type: "object",
        properties: %{
          summary: %{type: "string"}
        },
        required: ["summary"],
        additionalProperties: false
      }
    }
  }
  @system_prompt """
  You are an expert assistant specializing in analyzing the contents of PDF files. Your task is to carefully examine the provided PDF and deliver a concise, accurate, and insightful analysis.

  IMPORTANT:
  - Never include unescaped newlines, unescaped double quotes, or trailing commas.
  - The summary content should be formatted as valid markdown easily readable by humans, but do not include any code block markers (such as triple backticks).
  - Never include any keys other than \"summary\" in the JSON object.
  - Never include any output, comments, or explanations outside the JSON object.
  - Do not include control characters or non-printable Unicode in the summary.
  If you are unable to analyze the document for any reason (such as unreadable content, unsupported language, or missing information), you must still respond with the above JSON structure and provide an explanation in the \"summary\" field describing the issue. Never refuse to answer, never return an empty or invalid JSON, and never include any information outside of this JSON structure. Be objective, thorough, and avoid speculation.
  """
  @recv_timeout 10 * 60 * 1000

  def generate_summary(pdf_content, opts \\ []) when is_binary(pdf_content) do
    additional_prompt = Keyword.get(opts, :additional_prompt, "")
    filename = Keyword.get(opts, :filename, "document.pdf")

    user_content = [
      %{
        type: "file",
        file: %{
          filename: filename,
          file_data: "data:application/pdf;base64," <> Base.encode64(pdf_content)
        }
      }
    ]

    system_prompt =
      case additional_prompt do
        p when is_binary(p) and p != "" -> @system_prompt <> "\n\n" <> p
        _ -> @system_prompt
      end

    request = [
      model: @model,
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_content}
      ],
      response_format: @response_format
    ]

    config = %OpenAI.Config{http_options: [recv_timeout: @recv_timeout]}

    with {:ok, %{choices: [choice | _]}} <- OpenAI.chat_completion(request, config),
         cleaned_content <-
           choice["message"]["content"]
           |> String.replace(~r/^```json\s*|^```\s*|\s*```\s*$/m, "")
           |> String.trim(),
         {:ok, %{"summary" => summary}} <- Jason.decode(cleaned_content) do
      {:ok, summary}
    else
      {:ok, %{choices: []}} ->
        {:error, :no_choices_returned}

      {:error, reason} ->
        {:error, reason}

      error ->
        {:error, error}
    end
  end
end
