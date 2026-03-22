require "rails_helper"

RSpec.describe Parsers::Statements::InterPdfParser do
  it "extracts the statement header and line items from the real PDF" do
    credit_card = build(:credit_card, closing_day: 28, due_day: 5)

    result = described_class.new(
      file_path: Rails.root.join("doc", "inter.pdf"),
      credit_card: credit_card
    ).call

    expect(result.dig(:statement, :due_date)).to eq(Date.new(2026, 3, 5))
    expect(result.dig(:statement, :total_amount_cents)).to eq(649_417)
    expect(result.dig(:summary, :total_items)).to be > 50
    expect(result[:items].first[:description]).to eq("PAGAMENTO ON LINE")
    expect(result[:items].first[:ignored]).to be(true)
  end
end
