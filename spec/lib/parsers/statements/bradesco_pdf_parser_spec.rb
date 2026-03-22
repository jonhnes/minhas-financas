require "rails_helper"

RSpec.describe Parsers::Statements::BradescoPdfParser do
  it "extracts the statement header and line items from the real PDF" do
    credit_card = build(:credit_card, closing_day: 2, due_day: 15)

    result = described_class.new(
      file_path: Rails.root.join("doc", "Bradesco_Fatura-Sun Mar 22 2026 09:41:36 GMT-0300 (Horário Padrão de Brasília).pdf"),
      credit_card: credit_card
    ).call

    expect(result.dig(:statement, :due_date)).to eq(Date.new(2026, 3, 15))
    expect(result.dig(:statement, :total_amount_cents)).to eq(1_301_673)
    expect(result.dig(:summary, :total_items)).to be > 100
    expect(result[:items].any? { |item| item[:raw_holder_name] == "MARIA VANDELUCIA CARDOSO HENRI" }).to be(true)
    expect(result[:items].first[:ignored]).to be(true)
  end
end
