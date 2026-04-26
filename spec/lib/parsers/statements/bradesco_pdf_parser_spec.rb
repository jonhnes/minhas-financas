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

  it "extracts an open statement and tags it as open_statement" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 2, due_day: 15)
    stub_pdf_reader_fixture("bradesco_open_statement_pages")

    result = described_class.new(
      file_path: Rails.root.join("spec", "fixtures", "files", "test.pdf"),
      credit_card: credit_card
    ).call

    expect(result.dig(:statement, :due_date)).to eq(Date.new(2026, 4, 15))
    expect(result.dig(:statement, :total_amount_cents)).to eq(1_793_982)
    expect(result.dig(:statement, :metadata, "document_kind")).to eq("open_statement")
    expect(result.dig(:summary, :total_items)).to eq(26)
    expect(result[:items].map { |item| item[:raw_holder_name] }.uniq).to eq([
      "JONHNES L MENEZES",
      "FRANCISCA THAISA",
      "MARIA V C HENRIQUE"
    ])

    expect(result[:items].none? { |item| item[:description].match?(/SALDO ANTERIOR|Total para/i) }).to be(true)
    expect(result[:items].find { |item| item[:description] == "BABYCHICO" }).to include(
      occurred_on: Date.new(2025, 11, 8),
      raw_holder_name: "JONHNES L MENEZES"
    )
    expect(result[:items].find { |item| item[:description] == "Smiles Club Smil" }).to include(
      occurred_on: Date.new(2026, 1, 5)
    )
    expect(result[:items].find { |item| item[:description] == "HOTELCOM72064052" }[:occurred_on]).to eq(Date.new(2025, 7, 4))
  end

  it "extracts a partial statement from the current Bradesco invoice layout" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 2, due_day: 15)
    stub_pdf_reader_fixture("bradesco_partial_statement_pages")

    result = described_class.new(
      file_path: Rails.root.join("spec", "fixtures", "files", "test.pdf"),
      credit_card: credit_card
    ).call

    expect(result.dig(:statement, :due_date)).to eq(Date.new(2026, 5, 15))
    expect(result.dig(:statement, :period_start)).to eq(Date.new(2026, 4, 3))
    expect(result.dig(:statement, :period_end)).to eq(Date.new(2026, 5, 2))
    expect(result.dig(:statement, :total_amount_cents)).to eq(1_048_706)
    expect(result.dig(:statement, :metadata, "document_kind")).to eq("open_statement")
    expect(result.dig(:summary, :total_items)).to eq(5)
    expect(result.dig(:summary, :ignored_items)).to eq(1)

    expect(result[:items].find { |item| item[:description] == "ITALO SUPERMERCADOS" }).to include(
      occurred_on: Date.new(2026, 4, 23),
      amount_cents: 5_977,
      raw_holder_name: "JONHNES L MENEZES"
    )
    expect(result[:items].find { |item| item[:description] == "5 creditos 225QV1" }).to include(
      occurred_on: Date.new(2026, 4, 23)
    )

    installment_item = result[:items].find { |item| item[:description] == "RENTCARS ( 01/03 )" }
    expect(installment_item).to include(
      installment_detected: true,
      installment_number: 1,
      installment_total: 3,
      canonical_merchant_name: "RENTCARS"
    )

    old_installment_item = result[:items].find { |item| item[:description] == "HOTEIS.COM ( 05/10 )" }
    expect(old_installment_item).to include(
      occurred_on: Date.new(2026, 4, 16),
      purchase_occurred_on: Date.new(2025, 12, 16),
      raw_holder_name: "FRANCISCA THAISA"
    )

    expect(result[:items].find { |item| item[:description] == "SHOPEE *ATACADOINOVA" }).to include(
      amount_cents: -1_000,
      ignored: true
    )
    expect(result[:items].none? { |item| item[:description].match?(/SALDO ANTERIOR|PET LOVE/) }).to be(true)
  end
end
