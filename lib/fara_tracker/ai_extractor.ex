defmodule FaraTracker.AiExtractor do
  @moduledoc """
  AI-powered data extraction from FARA PDF documents.

  This module will integrate with OpenAI/Claude to extract structured data
  from FARA registration forms and supplemental statements.
  """

  require Logger

  @doc """
  Extracts structured data from a FARA registration PDF.

  ## Parameters
  - `pdf_content` - Binary content of the PDF file
  - `document_type` - Type of document (:registration_form, :exhibit, :supplement)

  ## Returns
  `{:ok, extracted_data}` or `{:error, reason}`
  """
  def extract_from_pdf(pdf_content, document_type \\ :registration_form) do
    # TODO: Implement actual AI extraction
    # This will:
    # 1. Convert PDF to text (using a PDF library)
    # 2. Send to OpenAI with structured prompt
    # 3. Parse the JSON response

    Logger.info("🤖 AI extraction for #{document_type} (#{byte_size(pdf_content)} bytes)")

    case document_type do
      :registration_form -> extract_registration_data(pdf_content)
      :exhibit -> extract_exhibit_data(pdf_content)
      :supplement -> extract_supplement_data(pdf_content)
      _ -> {:error, :unknown_document_type}
    end
  end

  # Placeholder implementations
  defp extract_registration_data(_pdf_content) do
    # TODO: Replace with actual OpenAI API call
    {:ok, %{
      agent_name: "Extracted Agent Name",
      agent_address: "Extracted Address",
      foreign_principal: "Extracted Principal",
      country: "Extracted Country",
      registration_date: Date.utc_today(),
      services_description: "Extracted services description"
    }}
  end

  defp extract_exhibit_data(_pdf_content) do
    # TODO: Extract financial data from exhibits
    {:ok, %{
      compensation_amount: 0,
      period_start: Date.utc_today(),
      period_end: Date.utc_today()
    }}
  end

  defp extract_supplement_data(_pdf_content) do
    # TODO: Extract supplemental statement data
    {:ok, %{
      additional_compensation: 0,
      activities_description: "Extracted activities"
    }}
  end

  @doc """
  The AI prompt template for extracting FARA data.
  This will be used when integrating with OpenAI.
  """
  def extraction_prompt do
    """
    You are an expert at extracting structured data from FARA (Foreign Agent Registration Act) documents.

    Extract the following information from this FARA registration document:

    1. Agent Information:
       - Full legal name of the agent/registrant
       - Business address
       - Principal contact information

    2. Foreign Principal Information:
       - Name of the foreign principal
       - Country of the foreign principal
       - Nature of the relationship

    3. Financial Information:
       - Total compensation received or agreed to be received
       - Payment terms and schedule
       - Any expenses or disbursements

    4. Services and Activities:
       - Description of services to be performed
       - Specific activities conducted for the foreign principal
       - Duration of the relationship

    5. Registration Details:
       - Registration date
       - Registration number (if available)
       - Effective dates of the arrangement

    Return the extracted data as a JSON object with the following structure:
    {
      "agent_name": "string",
      "agent_address": "string",
      "foreign_principal": "string",
      "country": "string",
      "total_compensation": "number",
      "services_description": "string",
      "registration_date": "YYYY-MM-DD",
      "latest_period_start": "YYYY-MM-DD",
      "latest_period_end": "YYYY-MM-DD",
      "status": "active"
    }

    Document text:
    """
  end
end
