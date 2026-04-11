require "rails_helper"

RSpec.describe Transactions::Create do
  it "creates the current installment and the future schedule for a clipboard-captured credit card purchase" do
    user = create(:user)
    credit_card = create(:credit_card, user: user)
    category = create(:category, user: user, name: "Assinaturas")

    transaction = user.transactions.new(
      credit_card: credit_card,
      category: category,
      transaction_type: "expense",
      impact_mode: "normal",
      amount_cents: 21_480,
      occurred_on: Date.new(2026, 4, 6),
      description: "IG*MYPROFIT",
      canonical_merchant_name: "IG*MYPROFIT",
      metadata: {
        "capture_source" => "clipboard",
        "capture_provider" => "bradesco_sms"
      }
    )

    created_transaction = described_class.new(
      transaction: transaction,
      installment: {
        enabled: true,
        current_number: 1,
        total_installments: 12,
        purchase_occurred_on: "2026-04-06",
        generate_future_installments: true
      }
    ).call

    future_transactions = user.transactions.where(
      installment_group_key: created_transaction.installment_group_key,
      auto_generated: true
    ).order(:installment_number)

    expect(created_transaction).to be_persisted
    expect(created_transaction.auto_generated).to be(false)
    expect(created_transaction.installment_number).to eq(1)
    expect(created_transaction.installment_total).to eq(12)
    expect(created_transaction.purchase_occurred_on).to eq(Date.new(2026, 4, 6))
    expect(created_transaction.metadata["installment"]).to include(
      "current_number" => 1,
      "total_installments" => 12,
      "purchase_occurred_on" => "2026-04-06",
      "group_key" => created_transaction.installment_group_key
    )
    expect(future_transactions.pluck(:installment_number)).to eq((2..12).to_a)
    expect(future_transactions.pluck(:description).uniq).to eq(["IG*MYPROFIT"])
  end

  it "rejects creating a duplicated installment schedule" do
    user = create(:user)
    credit_card = create(:credit_card, user: user)
    category = create(:category, user: user)
    existing_group_key = Installments::Support.group_key(
      credit_card_id: credit_card.id,
      canonical_merchant_name: "AUTO POSTO PETRO QUERUB",
      purchase_occurred_on: Date.new(2026, 4, 5),
      amount_cents: 27_860,
      installment_total: 3
    )

    create(
      :transaction,
      :credit_card_purchase,
      user: user,
      credit_card: credit_card,
      category: category,
      amount_cents: 27_860,
      occurred_on: Date.new(2026, 4, 5),
      description: "AUTO POSTO PETRO QUERUB",
      canonical_merchant_name: "AUTO POSTO PETRO QUERUB",
      installment_group_key: existing_group_key,
      installment_number: 1,
      installment_total: 3,
      purchase_occurred_on: Date.new(2026, 4, 5)
    )

    transaction = user.transactions.new(
      credit_card: credit_card,
      category: category,
      transaction_type: "expense",
      impact_mode: "normal",
      amount_cents: 27_860,
      occurred_on: Date.new(2026, 4, 5),
      description: "AUTO POSTO PETRO QUERUB",
      canonical_merchant_name: "AUTO POSTO PETRO QUERUB"
    )

    expect do
      described_class.new(
        transaction: transaction,
        installment: {
          enabled: true,
          current_number: 1,
          total_installments: 3,
          purchase_occurred_on: "2026-04-05",
          generate_future_installments: true
        }
      ).call
    end.to raise_error(ActiveRecord::RecordInvalid) { |error|
      expect(error.record.errors.full_messages).to include("Já existe a parcela 1/3 para esta compra.")
    }
  end
end
