require "rails_helper"
require_relative "../../../support/pdf_reader_fixture_helper"

RSpec.describe Parsers::Statements::BradescoPdfParser do
  include PdfReaderFixtureHelper

  it "extracts the statement header and line items from sanitized extracted pages" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 2, due_day: 15)
    stub_pdf_reader_fixture("bradesco_pages")

    result = described_class.new(
      file_path: Rails.root.join("spec", "fixtures", "files", "test.pdf"),
      credit_card: credit_card
    ).call

    expect(result.dig(:statement, :due_date)).to eq(Date.new(2026, 3, 15))
    expect(result.dig(:statement, :total_amount_cents)).to eq(1_301_673)
    expect(result.dig(:summary, :total_items)).to eq(4)
    expect(result[:items].any? { |item| item[:raw_holder_name] == "CLIENTE EXEMPLO" }).to be(true)
    expect(result[:items].first[:ignored]).to be(true)

    installment_item = result[:items].find { |item| item[:description] == "LOJA TESTE 01/03" }
    non_installment_item = result[:items].find { |item| item[:description] == "IFD*TESTE" }

    expect(installment_item).to include(
      occurred_on: Date.new(2026, 2, 25),
      installment_detected: true,
      installment_enabled: true,
      installment_number: 1,
      installment_total: 3,
      purchase_occurred_on: Date.new(2026, 2, 25),
      canonical_merchant_name: "LOJA TESTE"
    )
    expect(installment_item[:installment_group_key]).to be_present
    expect(installment_item.dig(:metadata, "installment")).to eq(
      "detected" => true,
      "current_number" => 1,
      "total_installments" => 3,
      "purchase_occurred_on" => "2026-02-25",
      "source_format" => "fractional_suffix"
    )
    expect(non_installment_item.dig(:metadata, "installment")).to be_nil
    expect(non_installment_item[:installment_detected]).to be(false)
  end
end
