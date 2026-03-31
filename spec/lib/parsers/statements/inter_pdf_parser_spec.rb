require "rails_helper"

RSpec.describe Parsers::Statements::InterPdfParser do
  it "extracts the statement header and line items from the real PDF" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)

    result = described_class.new(
      file_path: Rails.root.join("doc", "inter.pdf"),
      credit_card: credit_card
    ).call

    expect(result.dig(:statement, :due_date)).to eq(Date.new(2026, 3, 5))
    expect(result.dig(:statement, :total_amount_cents)).to eq(649_417)
    expect(result.dig(:summary, :total_items)).to be > 50
    expect(result[:items].first[:description]).to eq("PAGAMENTO ON LINE")
    expect(result[:items].first[:ignored]).to be(true)

    installment_item = result[:items].find { |item| item[:description] == "DL *Bookingcom40741 (Parcela 08 de 10)" }
    non_installment_item = result[:items].find { |item| item[:description] == "BISTRO DA VILA" }

    expect(installment_item).to include(
      occurred_on: Date.new(2026, 2, 2),
      installment_detected: true,
      installment_enabled: true,
      installment_number: 8,
      installment_total: 10,
      purchase_occurred_on: Date.new(2025, 7, 2),
      canonical_merchant_name: "DL *BOOKINGCOM40741"
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
end
