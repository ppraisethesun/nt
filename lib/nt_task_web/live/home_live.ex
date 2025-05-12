defmodule NtTaskWeb.HomeLive do
  use NtTaskWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:form, to_form(%{}))
      |> assign(:uploaded_file, nil)
      |> assign(:summary, nil)
      |> assign(:analyzing, false)
      |> allow_upload(:pdf,
        accept: ~w(.pdf),
        max_entries: 1,
        max_file_size: 500_000_000,
        auto_upload: true
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col min-h-screen">
      <main class="flex-grow flex flex-col items-center justify-center p-8">
        <.form
          for={@form}
          phx-change="validate"
          phx-submit="analyze_pdf"
          class="w-full max-w-lg flex flex-col items-center"
        >
          <label
            for={@uploads.pdf.ref}
            class="flex flex-col items-center justify-center w-full h-64 p-12 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:bg-gray-50"
            phx-drop-target={@uploads.pdf.ref}
          >
            <div class="flex flex-col items-center justify-center pt-5 pb-6">
              <svg
                class="w-8 h-8 mb-4 text-gray-500"
                aria-hidden="true"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 20 16"
              >
                <path
                  stroke="currentColor"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 13h3a3 3 0 0 0 0-6h-.025A5.56 5.56 0 0 0 16 6.5 5.5 5.5 0 0 0 5.207 5.021C5.137 5.017 5.071 5 5 5a4 4 0 0 0 0 8h2.167M10 15V6m0 0L8 8m2-2 2 2"
                />
              </svg>
              <p class="mb-2 text-sm text-gray-500">
                <span class="font-semibold">Click to upload</span> or drag and drop PDF here
              </p>
            </div>
            <.live_file_input upload={@uploads.pdf} class="hidden" />
          </label>

          <div :for={entry <- @uploads.pdf.entries} class="mt-4 w-full p-2 border rounded text-sm">
            <p>File: {entry.client_name}</p>
            <p>Progress: {entry.progress}%</p>
            <div :for={err <- upload_errors(@uploads.pdf, entry)} class="text-red-500">
              Error: {Atom.to_string(err)}
            </div>
          </div>

          <div :for={err <- upload_errors(@uploads.pdf)} class="mt-2 text-red-500 text-sm">
            {Atom.to_string(err)}
          </div>

          <div class="mt-6 w-full">
            <label for="additional-prompt" class="block text-sm font-medium text-gray-700 mb-1">
              Additional Prompt (Optional)
            </label>
            <.input
              type="textarea"
              id="additional-prompt"
              name="additional_prompt"
              rows="3"
              class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border border-gray-300 rounded-md p-2"
              placeholder="Enter any additional instructions here..."
              phx-debounce="500"
              field={@form[:additional_prompt]}
            />
          </div>

          <%= if @analyzing do %>
            <div class="mt-6 flex justify-center items-center w-full">
              <svg
                class="animate-spin h-8 w-8 text-indigo-600"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
              >
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                >
                </circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z">
                </path>
              </svg>
              <span class="ml-3 text-indigo-700 font-medium">Analyzing PDF...</span>
            </div>
          <% else %>
            <button
              type="submit"
              class="mt-6 w-full px-6 py-3 bg-indigo-600 text-white font-medium rounded-lg shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
              phx-disable-with="Analyzing..."
              disabled={
                Enum.any?(@uploads.pdf.entries, &(!&1.done?)) || @uploads.pdf.entries == [] ||
                  @uploads.pdf.errors != [] || @form.errors != []
              }
            >
              Analyze PDF
            </button>
          <% end %>
        </.form>

        <div :if={@summary} class="mt-8 w-full max-w-lg p-4 border rounded bg-gray-50">
          <h3 class="text-lg font-semibold mb-2">PDF Summary of {@uploaded_file.client_name}</h3>
          <div class="prose">
            {raw(@summary)}
          </div>
        </div>
      </main>
    </div>
    """
  end

  @impl true
  def handle_event("validate", params, socket) do
    socket = assign(socket, :form, to_form(params))

    {:noreply, socket}
  end

  @impl true
  def handle_event("analyze_pdf", params, socket) do
    [uploaded_file] =
      consume_uploaded_entries(socket, :pdf, fn %{path: path}, entry ->
        {:ok,
         %{
           content: File.read!(path),
           client_name: entry.client_name
         }}
      end)

    Task.Supervisor.async_nolink(NtTask.TaskSupervisor, fn ->
      with {:ok, summary_str} <-
             NtTask.LLMClient.generate_summary(uploaded_file.content,
               additional_prompt: params["additional_prompt"]
             ) do
        summary = Earmark.as_html!(summary_str)
        {:result, summary}
      else
        {:error, error} -> {:result, "error occured: #{inspect(error)}"}
      end
    end)

    socket =
      socket
      |> assign(:analyzing, true)
      |> assign(:uploaded_file, uploaded_file)

    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, {:result, summary}}, socket) do
    Process.demonitor(ref, [:flush])

    socket =
      socket
      |> assign(:summary, summary)
      |> assign(:analyzing, false)

    {:noreply, socket}
  end
end
