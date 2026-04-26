require "rails_helper"

RSpec.describe "API imports", type: :request do
  # Real PDFs under doc/ stay local-only for manual parser debugging; CI uses tracked fixtures.
  def test_pdf_fixture_path
    Rails.root.join("spec", "fixtures", "files", "test.pdf")
  end

  def csrf_headers
    get "/api/v1/auth/csrf", as: :json
    {
      "ACCEPT" => "application/json",
      "X-CSRF-Token" => response.parsed_body.dig("data", "csrf_token")
    }
  end

  def build_bradesco_parser_item(line_index:, occurred_on:, description:, amount_cents:, raw_holder_name: nil, canonical_merchant_name: nil, ignored: false)
    canonical_merchant_name ||= ActiveSupport::Inflector.transliterate(description).upcase

    {
      line_index: line_index,
      occurred_on: occurred_on,
      description: description,
      amount_cents: amount_cents,
      transaction_type: "expense",
      impact_mode: ignored ? "informational" : "normal",
      category_id: nil,
      card_holder_id: nil,
      canonical_merchant_name: canonical_merchant_name,
      raw_holder_name: raw_holder_name,
      status: "pending_review",
      ignored: ignored,
      metadata: {
        "provider_key" => "bradesco_pdf",
        "parsed_identity" => {
          "occurred_on" => occurred_on.iso8601,
          "description" => description,
          "amount_cents" => amount_cents,
          "canonical_merchant_name" => canonical_merchant_name
        }
      },
      installment_detected: false,
      installment_enabled: false,
      installment_group_key: nil,
      installment_number: nil,
      installment_total: nil,
      purchase_occurred_on: nil
    }
  end

  def build_bradesco_parser_result(document_kind:, items:, due_date: Date.new(2026, 4, 5), total_amount_cents: nil)
    {
      statement: {
        period_start: Date.new(2026, 3, 1),
        period_end: Date.new(2026, 3, 31),
        due_date: due_date,
        total_amount_cents: total_amount_cents || items.reject { |item| item[:ignored] }.sum { |item| item[:amount_cents] },
        status: "open",
        metadata: {
          "provider_key" => "bradesco_pdf",
          "document_kind" => document_kind
        }
      },
      summary: {
        total_items: items.size,
        ignored_items: items.count { |item| item[:ignored] },
        reviewable_items: items.count { |item| !item[:ignored] }
      },
      items: items,
      page_count: 2
    }
  end

  it "uploads a PDF and produces a reviewable import" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    installment_group_key = Installments::Support.group_key(
      credit_card_id: credit_card.id,
      canonical_merchant_name: "RESERVA TESTE",
      purchase_occurred_on: Date.new(2025, 7, 2),
      amount_cents: 35_000,
      installment_total: 10
    )
    parser_result = {
      statement: {
        period_start: Date.new(2026, 1, 29),
        period_end: Date.new(2026, 2, 28),
        due_date: Date.new(2026, 3, 5),
        total_amount_cents: 649_417,
        status: "open",
        metadata: { "provider_key" => "inter_pdf" }
      },
      summary: {
        total_items: 2,
        ignored_items: 1,
        reviewable_items: 1
      },
      items: [
        {
          line_index: 1,
          occurred_on: Date.new(2026, 2, 1),
          description: "PAGAMENTO ON LINE",
          amount_cents: 12_000,
          transaction_type: "expense",
          impact_mode: "informational",
          category_id: nil,
          card_holder_id: nil,
          canonical_merchant_name: "PAGAMENTO ON LINE",
          raw_holder_name: nil,
          status: "pending_review",
          ignored: true,
          metadata: { "provider_key" => "inter_pdf", "card_mask" => "4321" },
          installment_detected: false,
          installment_enabled: false,
          installment_group_key: nil,
          installment_number: nil,
          installment_total: nil,
          purchase_occurred_on: nil
        },
        {
          line_index: 2,
          occurred_on: Date.new(2026, 2, 2),
          description: "RESERVA TESTE (Parcela 08 de 10)",
          amount_cents: 35_000,
          transaction_type: "expense",
          impact_mode: "normal",
          category_id: nil,
          card_holder_id: nil,
          canonical_merchant_name: "RESERVA TESTE",
          raw_holder_name: nil,
          status: "pending_review",
          ignored: false,
          metadata: {
            "provider_key" => "inter_pdf",
            "card_mask" => "4321",
            "installment" => {
              "detected" => true,
              "current_number" => 8,
              "total_installments" => 10,
              "purchase_occurred_on" => "2025-07-02",
              "source_format" => "parenthesized_parcela"
            }
          },
          installment_detected: true,
          installment_enabled: true,
          installment_group_key: installment_group_key,
          installment_number: 8,
          installment_total: 10,
          purchase_occurred_on: Date.new(2025, 7, 2)
        }
      ],
      page_count: 1
    }
    parser_instance = instance_double(Parsers::Statements::InterPdfParser, call: parser_result)

    sign_in user
    allow(Imports::ParserRegistry).to receive(:fetch).with("inter_pdf").and_return(Parsers::Statements::InterPdfParser)
    allow(Parsers::Statements::InterPdfParser).to receive(:new).and_return(parser_instance)

    post "/api/v1/imports",
      params: {
        import: {
          credit_card_id: credit_card.id,
          provider_key: "inter_pdf",
          source_file: Rack::Test::UploadedFile.new(test_pdf_fixture_path, "application/pdf")
        }
      },
      headers: csrf_headers

    expect(response).to have_http_status(:created)

    import_record = Import.last
    expect(import_record).to be_review_pending
    expect(import_record.import_items.count).to eq(2)
    expect(import_record.summary_payload).to include("total_items" => 2, "reviewable_items" => 1)
    expect(import_record.raw_payload).to include("filename" => "test.pdf", "page_count" => 1)
  end

  it "rejects PDFs larger than 50 MB" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)

    sign_in user
    allow_any_instance_of(ActiveStorage::Blob).to receive(:byte_size).and_return(Import::MAX_SOURCE_FILE_SIZE + 1)

    expect do
      post "/api/v1/imports",
        params: {
          import: {
            credit_card_id: credit_card.id,
            provider_key: "inter_pdf",
            source_file: Rack::Test::UploadedFile.new(test_pdf_fixture_path, "application/pdf")
          }
        },
        headers: csrf_headers
    end.not_to change(Import, :count)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors")).to include(a_string_matching(/deve ter no máximo 50 MB/))
  end

  it "uploads a Bradesco open statement PDF and exposes document_kind as open_statement" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    parser_result = build_bradesco_parser_result(
      document_kind: "open_statement",
      items: [
        build_bradesco_parser_item(
          line_index: 1,
          occurred_on: Date.new(2026, 4, 2),
          description: "UBER * PENDING",
          canonical_merchant_name: "UBER * PENDING",
          amount_cents: 1_185,
          raw_holder_name: "JONHNES L MENEZES"
        )
      ],
      due_date: Date.new(2026, 4, 15),
      total_amount_cents: 1_185
    )
    parser_instance = instance_double(Parsers::Statements::BradescoPdfParser, call: parser_result)

    sign_in user
    allow(Imports::ParserRegistry).to receive(:fetch).with("bradesco_pdf").and_return(Parsers::Statements::BradescoPdfParser)
    allow(Parsers::Statements::BradescoPdfParser).to receive(:new).and_return(parser_instance)

    post "/api/v1/imports",
      params: {
        import: {
          credit_card_id: credit_card.id,
          provider_key: "bradesco_pdf",
          source_file: Rack::Test::UploadedFile.new(test_pdf_fixture_path, "application/pdf")
        }
      },
      headers: csrf_headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "document_kind")).to eq("open_statement")

    import_record = Import.last
    expect(import_record).to be_review_pending
    expect(import_record.document_kind).to eq("open_statement")
    expect(import_record.summary_payload).to include("total_items" => 1, "reviewable_items" => 1)
  end

  it "reuses review adjustments when a Bradesco final statement replaces an open draft" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    holder = create(:card_holder, credit_card: credit_card, name: "Jonhnes L Menezes")
    open_result = build_bradesco_parser_result(
      document_kind: "open_statement",
      items: [
        build_bradesco_parser_item(
          line_index: 1,
          occurred_on: Date.new(2026, 4, 2),
          description: "UBER * PENDING",
          canonical_merchant_name: "UBER * PENDING",
          amount_cents: 1_185,
          raw_holder_name: "JONHNES L MENEZES"
        )
      ],
      due_date: Date.new(2026, 4, 15),
      total_amount_cents: 1_185
    )
    final_result = build_bradesco_parser_result(
      document_kind: "final_statement",
      items: [
        build_bradesco_parser_item(
          line_index: 1,
          occurred_on: Date.new(2026, 4, 2),
          description: "UBER * PENDING",
          canonical_merchant_name: "UBER * PENDING",
          amount_cents: 1_185,
          raw_holder_name: "JONHNES L MENEZES"
        ),
        build_bradesco_parser_item(
          line_index: 2,
          occurred_on: Date.new(2026, 4, 3),
          description: "PAG*STREAMING",
          canonical_merchant_name: "PAG*STREAMING",
          amount_cents: 2_290,
          raw_holder_name: "JONHNES L MENEZES"
        )
      ],
      due_date: Date.new(2026, 4, 15),
      total_amount_cents: 3_475
    )
    open_parser_instance = instance_double(Parsers::Statements::BradescoPdfParser, call: open_result)
    final_parser_instance = instance_double(Parsers::Statements::BradescoPdfParser, call: final_result)

    sign_in user
    headers = csrf_headers

    allow(Imports::ParserRegistry).to receive(:fetch).with("bradesco_pdf").and_return(Parsers::Statements::BradescoPdfParser)
    allow(Parsers::Statements::BradescoPdfParser).to receive(:new).and_return(open_parser_instance, final_parser_instance)

    post "/api/v1/imports",
      params: {
        import: {
          credit_card_id: credit_card.id,
          provider_key: "bradesco_pdf",
          source_file: Rack::Test::UploadedFile.new(test_pdf_fixture_path, "application/pdf")
        }
      },
      headers: headers

    open_import = Import.last
    open_item = open_import.import_items.sole
    open_item.update!(
      occurred_on: Date.new(2026, 4, 8),
      description: "UBER * CORRIGIDO",
      amount_cents: 1_300,
      category: category,
      card_holder: holder,
      impact_mode: :third_party
    )

    post "/api/v1/imports",
      params: {
        import: {
          credit_card_id: credit_card.id,
          provider_key: "bradesco_pdf",
          source_file: Rack::Test::UploadedFile.new(test_pdf_fixture_path, "application/pdf")
        }
      },
      headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "document_kind")).to eq("final_statement")
    expect(response.parsed_body.dig("data", "comparison", "mode")).to eq("replacing_open_draft")

    final_import = Import.order(:id).last
    expect(open_import.reload).to be_superseded
    expect(final_import.document_kind).to eq("final_statement")
    expect(final_import.comparison_payload).to include(
      "mode" => "replacing_open_draft",
      "matched_existing_count" => 1,
      "new_items_count" => 1,
      "missing_from_final_count" => 0
    )

    get "/api/v1/imports/#{final_import.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "comparison", "mode")).to eq("replacing_open_draft")

    matched_item = final_import.reload.import_items.order(:line_index).first
    expect(matched_item.occurred_on).to eq(Date.new(2026, 4, 8))
    expect(matched_item.description).to eq("UBER * CORRIGIDO")
    expect(matched_item.amount_cents).to eq(1_300)
    expect(matched_item.category_id).to eq(category.id)
    expect(matched_item.card_holder_id).to eq(holder.id)
    expect(matched_item.impact_mode).to eq("third_party")
  end

  it "reuses review adjustments when a Bradesco open statement refresh replaces an open draft" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    holder = create(:card_holder, credit_card: credit_card, name: "Jonhnes L Menezes")
    first_result = build_bradesco_parser_result(
      document_kind: "open_statement",
      items: [
        build_bradesco_parser_item(
          line_index: 1,
          occurred_on: Date.new(2026, 4, 2),
          description: "UBER * PENDING",
          canonical_merchant_name: "UBER * PENDING",
          amount_cents: 1_185,
          raw_holder_name: "JONHNES L MENEZES"
        )
      ],
      due_date: Date.new(2026, 4, 15)
    )
    refresh_result = build_bradesco_parser_result(
      document_kind: "open_statement",
      items: [
        build_bradesco_parser_item(
          line_index: 1,
          occurred_on: Date.new(2026, 4, 2),
          description: "UBER * PENDING",
          canonical_merchant_name: "UBER * PENDING",
          amount_cents: 1_185,
          raw_holder_name: "JONHNES L MENEZES"
        ),
        build_bradesco_parser_item(
          line_index: 2,
          occurred_on: Date.new(2026, 4, 3),
          description: "PAG*STREAMING",
          canonical_merchant_name: "PAG*STREAMING",
          amount_cents: 2_290,
          raw_holder_name: "JONHNES L MENEZES"
        )
      ],
      due_date: Date.new(2026, 4, 15)
    )
    first_parser_instance = instance_double(Parsers::Statements::BradescoPdfParser, call: first_result)
    refresh_parser_instance = instance_double(Parsers::Statements::BradescoPdfParser, call: refresh_result)

    sign_in user
    headers = csrf_headers

    allow(Imports::ParserRegistry).to receive(:fetch).with("bradesco_pdf").and_return(Parsers::Statements::BradescoPdfParser)
    allow(Parsers::Statements::BradescoPdfParser).to receive(:new).and_return(first_parser_instance, refresh_parser_instance)

    post "/api/v1/imports",
      params: {
        import: {
          credit_card_id: credit_card.id,
          provider_key: "bradesco_pdf",
          source_file: Rack::Test::UploadedFile.new(test_pdf_fixture_path, "application/pdf")
        }
      },
      headers: headers

    first_import = Import.last
    first_item = first_import.import_items.sole
    first_item.update!(
      occurred_on: Date.new(2026, 4, 8),
      description: "UBER * CORRIGIDO",
      amount_cents: 1_300,
      category: category,
      card_holder: holder,
      impact_mode: :third_party
    )

    post "/api/v1/imports",
      params: {
        import: {
          credit_card_id: credit_card.id,
          provider_key: "bradesco_pdf",
          source_file: Rack::Test::UploadedFile.new(test_pdf_fixture_path, "application/pdf")
        }
      },
      headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "document_kind")).to eq("open_statement")
    expect(response.parsed_body.dig("data", "comparison", "mode")).to eq("refreshing_open_draft")

    refresh_import = Import.order(:id).last
    expect(first_import.reload).to be_superseded
    expect(refresh_import.comparison_payload).to include(
      "mode" => "refreshing_open_draft",
      "matched_existing_count" => 1,
      "new_items_count" => 1
    )

    matched_item = refresh_import.reload.import_items.order(:line_index).first
    expect(matched_item.occurred_on).to eq(Date.new(2026, 4, 8))
    expect(matched_item.description).to eq("UBER * CORRIGIDO")
    expect(matched_item.amount_cents).to eq(1_300)
    expect(matched_item.category_id).to eq(category.id)
    expect(matched_item.card_holder_id).to eq(holder.id)
    expect(matched_item.impact_mode).to eq("third_party")
  end

  it "shows a comparison against an existing open Bradesco statement before confirmation" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    statement = create(:statement,
      credit_card: credit_card,
      period_start: Date.new(2026, 3, 1),
      period_end: Date.new(2026, 3, 31),
      due_date: Date.new(2026, 4, 15),
      total_amount_cents: 1_185,
      metadata: {
        "provider_key" => "bradesco_pdf",
        "document_kind" => "open_statement"
      })
    matched_transaction = create(:transaction,
      :credit_card_purchase,
      user: user,
      credit_card: credit_card,
      category: category,
      statement: statement,
      description: "UBER * PENDING",
      canonical_merchant_name: "UBER * PENDING",
      amount_cents: 1_185,
      occurred_on: Date.new(2026, 4, 2))
    parser_result = build_bradesco_parser_result(
      document_kind: "final_statement",
      items: [
        build_bradesco_parser_item(
          line_index: 1,
          occurred_on: Date.new(2026, 4, 2),
          description: "UBER * PENDING",
          canonical_merchant_name: "UBER * PENDING",
          amount_cents: 1_185,
          raw_holder_name: "JONHNES L MENEZES"
        ),
        build_bradesco_parser_item(
          line_index: 2,
          occurred_on: Date.new(2026, 4, 3),
          description: "PAG*STREAMING",
          canonical_merchant_name: "PAG*STREAMING",
          amount_cents: 2_290,
          raw_holder_name: "JONHNES L MENEZES"
        )
      ],
      due_date: Date.new(2026, 4, 15),
      total_amount_cents: 3_475
    )
    parser_instance = instance_double(Parsers::Statements::BradescoPdfParser, call: parser_result)

    sign_in user
    headers = csrf_headers

    allow(Imports::ParserRegistry).to receive(:fetch).with("bradesco_pdf").and_return(Parsers::Statements::BradescoPdfParser)
    allow(Parsers::Statements::BradescoPdfParser).to receive(:new).and_return(parser_instance)

    post "/api/v1/imports",
      params: {
        import: {
          credit_card_id: credit_card.id,
          provider_key: "bradesco_pdf",
          source_file: Rack::Test::UploadedFile.new(test_pdf_fixture_path, "application/pdf")
        }
      },
      headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "comparison", "mode")).to eq("finalizing_existing_open_statement")

    final_import = Import.last

    get "/api/v1/imports/#{final_import.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "comparison")).to include(
      "mode" => "finalizing_existing_open_statement",
      "existing_statement_id" => statement.id,
      "matched_existing_count" => 1,
      "new_items_count" => 1,
      "missing_from_final_count" => 0
    )

    matched_item = response.parsed_body.dig("data", "items").find { |item| item.fetch("description") == "UBER * PENDING" }
    new_item = response.parsed_body.dig("data", "items").find { |item| item.fetch("description") == "PAG*STREAMING" }

    expect(matched_item).to include(
      "comparison_status" => "matched_existing_statement_transaction",
      "matched_transaction_id" => matched_transaction.id
    )
    expect(new_item).to include(
      "comparison_status" => "new_item",
      "matched_transaction_id" => nil
    )
  end

  it "shows a comparison when refreshing an existing open Bradesco statement" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    statement = create(:statement,
      credit_card: credit_card,
      period_start: Date.new(2026, 3, 1),
      period_end: Date.new(2026, 3, 31),
      due_date: Date.new(2026, 4, 15),
      total_amount_cents: 3_475,
      metadata: {
        "provider_key" => "bradesco_pdf",
        "document_kind" => "open_statement"
      })
    matched_transaction = create(:transaction,
      :credit_card_purchase,
      user: user,
      credit_card: credit_card,
      category: category,
      statement: statement,
      description: "UBER * PENDING",
      canonical_merchant_name: "UBER * PENDING",
      amount_cents: 1_185,
      occurred_on: Date.new(2026, 4, 2))
    missing_transaction = create(:transaction,
      :credit_card_purchase,
      user: user,
      credit_card: credit_card,
      category: category,
      statement: statement,
      description: "ANTIGO ITEM",
      canonical_merchant_name: "ANTIGO ITEM",
      amount_cents: 9_999,
      occurred_on: Date.new(2026, 4, 1))
    parser_result = build_bradesco_parser_result(
      document_kind: "open_statement",
      items: [
        build_bradesco_parser_item(
          line_index: 1,
          occurred_on: Date.new(2026, 4, 2),
          description: "UBER * PENDING",
          canonical_merchant_name: "UBER * PENDING",
          amount_cents: 1_185,
          raw_holder_name: "JONHNES L MENEZES"
        )
      ],
      due_date: Date.new(2026, 4, 15),
      total_amount_cents: 1_185
    )
    parser_instance = instance_double(Parsers::Statements::BradescoPdfParser, call: parser_result)

    sign_in user
    headers = csrf_headers

    allow(Imports::ParserRegistry).to receive(:fetch).with("bradesco_pdf").and_return(Parsers::Statements::BradescoPdfParser)
    allow(Parsers::Statements::BradescoPdfParser).to receive(:new).and_return(parser_instance)

    post "/api/v1/imports",
      params: {
        import: {
          credit_card_id: credit_card.id,
          provider_key: "bradesco_pdf",
          source_file: Rack::Test::UploadedFile.new(test_pdf_fixture_path, "application/pdf")
        }
      },
      headers: headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "comparison")).to include(
      "mode" => "refreshing_existing_open_statement",
      "existing_statement_id" => statement.id,
      "matched_existing_count" => 1,
      "new_items_count" => 0,
      "missing_from_final_count" => 1
    )
    expect(response.parsed_body.dig("data", "comparison", "missing_from_final_transactions").sole).to include(
      "transaction_id" => missing_transaction.id,
      "description" => "ANTIGO ITEM"
    )
    expect(response.parsed_body.dig("data", "can_confirm")).to be(true)

    matched_item = Import.last.import_items.sole
    expect(matched_item.category_id).to eq(category.id)
    expect(matched_item.metadata).to include(
      "comparison_status" => "matched_existing_statement_transaction",
      "matched_transaction_id" => matched_transaction.id
    )
  end

  it "shows, edits and confirms a reviewed import" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    installment_group_key = Installments::Support.group_key(
      credit_card_id: credit_card.id,
      canonical_merchant_name: "MERCADO REVISADO",
      purchase_occurred_on: Date.new(2026, 2, 10),
      amount_cents: 12_390,
      installment_total: 2
    )
    import_record = create(:import, user: user, credit_card: credit_card)
    import_item = create(:import_item,
      import: import_record,
      category: nil,
      occurred_on: Date.new(2026, 3, 10),
      description: "Mercado revisado",
      canonical_merchant_name: "MERCADO REVISADO",
      installment_detected: true,
      installment_enabled: true,
      installment_group_key: installment_group_key,
      installment_number: 2,
      installment_total: 2,
      purchase_occurred_on: Date.new(2026, 2, 10),
      metadata: {
        "installment" => {
          "detected" => true,
          "current_number" => 2,
          "total_installments" => 2,
          "purchase_occurred_on" => "2026-02-10",
          "source_format" => "parenthesized_parcela"
        }
      })

    sign_in user
    headers = csrf_headers

    get "/api/v1/imports/#{import_record.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "items", 0, "id")).to eq(import_item.id)
    expect(response.parsed_body.dig("data", "items", 0, "installment")).to include(
      "detected" => true,
      "enabled" => true,
      "group_key" => installment_group_key,
      "current_number" => 2,
      "total_installments" => 2,
      "purchase_occurred_on" => "2026-02-10"
    )

    patch "/api/v1/imports/#{import_record.id}",
      params: {
        import: {
          period_start: "2026-01-29",
          period_end: "2026-02-28",
          due_date: "2026-03-05",
          total_amount_cents: 649_417
        }
      }.to_json,
      headers: headers.merge("CONTENT_TYPE" => "application/json")

    expect(response).to have_http_status(:ok)
    expect(import_record.reload.statement_payload["due_date"]).to eq("2026-03-05")

    patch "/api/v1/import_items/#{import_item.id}",
      params: {
        import_item: {
          occurred_on: "2026-02-10",
          description: "Mercado revisado",
          amount_cents: 12_390,
          category_id: category.id,
          impact_mode: "normal",
          ignored: false,
          installment_enabled: false
        }
      }.to_json,
      headers: headers.merge("CONTENT_TYPE" => "application/json")

    expect(response).to have_http_status(:ok)
    expect(import_item.reload.category_id).to eq(category.id)
    expect(import_item.reload.installment_enabled).to be(false)

    post "/api/v1/imports/#{import_record.id}/confirm", headers: headers

    expect(response).to have_http_status(:ok)
    expect(import_record.reload).to be_confirmed
    expect(import_record.statement).to be_present

    get "/api/v1/statements?credit_card_id=#{credit_card.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", 0, "id")).to eq(import_record.statement_id)
  end

  it "deletes a pending import" do
    user = create(:user)
    import_record = create(:import, user: user)
    import_item = create(:import_item, import: import_record)

    sign_in user

    delete "/api/v1/imports/#{import_record.id}", headers: csrf_headers

    expect(response).to have_http_status(:no_content)
    expect(Import.exists?(import_record.id)).to be(false)
    expect(ImportItem.exists?(import_item.id)).to be(false)
  end

  it "returns 422 when trying to delete a superseded import" do
    user = create(:user)
    import_record = create(:import, user: user, provider_key: :bradesco_pdf, status: :superseded)
    create(:import_item, import: import_record)

    sign_in user

    delete "/api/v1/imports/#{import_record.id}", headers: csrf_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors").join(" ")).to match(/foi substituída por outra revisão/i)
    expect(Import.exists?(import_record.id)).to be(true)
  end

  it "deletes a confirmed import and rolls back statement plus generated transactions" do
    user = create(:user)
    payment_account = create(:account, user: user, name: "Conta principal")
    credit_card = create(:credit_card, user: user, payment_account: payment_account, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    statement = create(:statement, credit_card: credit_card)
    import_record = create(:import,
      user: user,
      credit_card: credit_card,
      statement: statement,
      status: :confirmed,
      confirmed_at: Time.zone.parse("2026-03-22 21:00:00"))
    import_item = create(:import_item, import: import_record, category: category, status: :imported)
    transaction = create(:transaction,
      :credit_card_purchase,
      user: user,
      credit_card: credit_card,
      category: category,
      statement: statement,
      import_item: import_item)
    import_item.update!(linked_transaction: transaction)
    future_placeholder = create(:transaction,
      :credit_card_purchase,
      user: user,
      credit_card: credit_card,
      category: category,
      auto_generated: true,
      metadata: { "generated_from_import_id" => import_record.id })

    sign_in user
    headers = csrf_headers

    delete "/api/v1/imports/#{import_record.id}", headers: headers

    expect(response).to have_http_status(:no_content)
    expect(Import.exists?(import_record.id)).to be(false)
    expect(ImportItem.exists?(import_item.id)).to be(false)
    expect(Transaction.exists?(transaction.id)).to be(false)
    expect(Transaction.exists?(future_placeholder.id)).to be(false)
    expect(Statement.exists?(statement.id)).to be(false)
    expect(CreditCard.exists?(credit_card.id)).to be(true)
    expect(Account.exists?(payment_account.id)).to be(true)

    get "/api/v1/credit_cards", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |record| record.fetch("id") }).to include(credit_card.id)

    get "/api/v1/accounts", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |record| record.fetch("id") }).to include(payment_account.id)

    get "/api/v1/credit_cards/selectable", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |record| record.fetch("id") }).to include(credit_card.id)

    get "/api/v1/imports", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data")).to be_empty
  end

  it "returns 422 when a confirmed import cannot be rolled back safely" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    statement = create(:statement, credit_card: credit_card)
    import_record = create(:import,
      user: user,
      credit_card: credit_card,
      statement: statement,
      status: :confirmed,
      confirmed_at: Time.zone.parse("2026-03-22 21:00:00"))
    import_item = create(:import_item, import: import_record, category: category, status: :imported)
    transaction = create(:transaction,
      :credit_card_purchase,
      user: user,
      credit_card: credit_card,
      category: category,
      statement: statement,
      import_item: import_item)
    import_item.update!(linked_transaction: transaction)
    extra_transaction = create(:transaction,
      :credit_card_purchase,
      user: user,
      credit_card: credit_card,
      category: category,
      statement: statement)

    sign_in user

    delete "/api/v1/imports/#{import_record.id}", headers: csrf_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors").join(" ")).to match(/fatura já possui lançamentos fora desta importação/i)
    expect(Import.exists?(import_record.id)).to be(true)
    expect(Transaction.exists?(transaction.id)).to be(true)
    expect(Transaction.exists?(extra_transaction.id)).to be(true)
    expect(Statement.exists?(statement.id)).to be(true)
  end

  it "returns 422 when trying to delete a Bradesco import already reconciled with another import" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    statement = create(:statement,
      credit_card: credit_card,
      metadata: {
        "provider_key" => "bradesco_pdf",
        "document_kind" => "final_statement"
      })
    import_record = create(:import,
      user: user,
      credit_card: credit_card,
      statement: statement,
      provider_key: :bradesco_pdf,
      status: :confirmed,
      confirmed_at: Time.zone.parse("2026-03-22 21:00:00"))
    create(:import,
      user: user,
      credit_card: credit_card,
      statement: statement,
      provider_key: :bradesco_pdf,
      status: :confirmed,
      confirmed_at: Time.zone.parse("2026-03-23 09:00:00"))

    sign_in user

    delete "/api/v1/imports/#{import_record.id}", headers: csrf_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors").join(" ")).to match(/participa de uma reconciliação com outra importação/i)
    expect(Import.exists?(import_record.id)).to be(true)
    expect(Statement.exists?(statement.id)).to be(true)
  end

  it "isolates imports by user" do
    owner = create(:user)
    stranger = create(:user)
    import_record = create(:import, user: owner)

    sign_in stranger

    get "/api/v1/imports/#{import_record.id}", headers: csrf_headers

    expect(response).to have_http_status(:not_found)
  end

  it "does not allow deleting imports from another user" do
    owner = create(:user)
    stranger = create(:user)
    import_record = create(:import, user: owner)

    sign_in stranger

    delete "/api/v1/imports/#{import_record.id}", headers: csrf_headers

    expect(response).to have_http_status(:not_found)
  end
end
