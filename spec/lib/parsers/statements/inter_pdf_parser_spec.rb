require "rails_helper"
require "tempfile"
require_relative "../../../support/pdf_reader_fixture_helper"

RSpec.describe Parsers::Statements::InterPdfParser do
  include PdfReaderFixtureHelper

  it "extracts the statement header and line items from sanitized extracted pages" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    stub_pdf_reader_fixture("inter_pages")

    result = described_class.new(
      file_path: Rails.root.join("spec", "fixtures", "files", "test.pdf"),
      credit_card: credit_card
    ).call

    expect(result.dig(:statement, :due_date)).to eq(Date.new(2026, 3, 5))
    expect(result.dig(:statement, :total_amount_cents)).to eq(649_417)
    expect(result.dig(:summary, :total_items)).to eq(4)
    expect(result[:items].first[:description]).to eq("PAGAMENTO ON LINE")
    expect(result[:items].first[:ignored]).to be(true)

    installment_item = result[:items].find { |item| item[:description] == "RESERVA TESTE (Parcela 08 de 10)" }
    non_installment_item = result[:items].find { |item| item[:description] == "BISTRO TESTE" }

    expect(installment_item).to include(
      occurred_on: Date.new(2026, 2, 2),
      installment_detected: true,
      installment_enabled: true,
      installment_number: 8,
      installment_total: 10,
      purchase_occurred_on: Date.new(2025, 7, 2),
      canonical_merchant_name: "RESERVA TESTE"
    )
    expect(installment_item[:installment_group_key]).to be_present
    expect(installment_item.dig(:metadata, "installment")).to eq(
      "detected" => true,
      "current_number" => 8,
      "total_installments" => 10,
      "purchase_occurred_on" => "2025-07-02",
      "source_format" => "parenthesized_parcela"
    )
    expect(non_installment_item.dig(:metadata, "installment")).to be_nil
    expect(non_installment_item[:installment_detected]).to be(false)
  end

  it "extracts the current Inter statement layout" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    stub_pdf_reader_fixture("inter_current_statement_pages")

    result = described_class.new(
      file_path: Rails.root.join("spec", "fixtures", "files", "test.pdf"),
      credit_card: credit_card
    ).call

    expect(result.dig(:statement, :due_date)).to eq(Date.new(2026, 5, 5))
    expect(result.dig(:statement, :period_start)).to eq(Date.new(2026, 3, 29))
    expect(result.dig(:statement, :period_end)).to eq(Date.new(2026, 4, 28))
    expect(result.dig(:statement, :total_amount_cents)).to eq(908_666)
    expect(result.dig(:statement, :metadata)).to eq("provider_key" => "inter_pdf")
    expect(result.dig(:summary, :total_items)).to eq(7)
    expect(result.dig(:summary, :ignored_items)).to eq(2)
    expect(result.dig(:summary, :reviewable_items)).to eq(5)

    expect(result[:items].map { |item| item.dig(:metadata, "card_mask") }.uniq).to eq([
      "5554****8111",
      "5361****5381",
      "5554****1751"
    ])

    expect(result[:items].find { |item| item[:description] == "PAGAMENTO ON LINE" }).to include(
      amount_cents: -547_573,
      ignored: true,
      impact_mode: "informational"
    )
    expect(result[:items].find { |item| item[:description] == "IFD*A ANGELONI CIA LTD" && item[:amount_cents].negative? }).to include(
      amount_cents: -3_550,
      ignored: true,
      impact_mode: "informational"
    )

    current_installment = result[:items].find { |item| item[:description] == "AMAZON MARKETPLACE (Parcela 02 de 02)" }
    expect(current_installment).to include(
      occurred_on: Date.new(2026, 4, 19),
      installment_detected: true,
      installment_enabled: true,
      installment_number: 2,
      installment_total: 2,
      purchase_occurred_on: Date.new(2026, 3, 19),
      canonical_merchant_name: "AMAZON MARKETPLACE"
    )
    expect(current_installment.dig(:metadata, "installment")).to include(
      "current_number" => 2,
      "total_installments" => 2,
      "purchase_occurred_on" => "2026-03-19"
    )
  end

  it "normalizes PDFs with bytes before the PDF header before reading" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    reader = stub_pdf_reader_fixture("inter_current_statement_pages")
    captured_path = nil
    prefixed_pdf = Tempfile.new(["inter-prefixed", ".pdf"])
    prefixed_pdf.binmode
    prefixed_pdf.write("\0" * 32)
    prefixed_pdf.write("%PDF-1.7\n%%EOF\n")
    prefixed_pdf.flush

    allow(PDF::Reader).to receive(:new) do |path|
      captured_path = path
      reader
    end

    result = described_class.new(
      file_path: prefixed_pdf.path,
      credit_card: credit_card
    ).call

    expect(captured_path).not_to eq(prefixed_pdf.path)
    expect(File.binread(captured_path, 5)).to eq("%PDF-")
    expect(result.dig(:statement, :due_date)).to eq(Date.new(2026, 5, 5))
  ensure
    prefixed_pdf&.close!
  end
end
