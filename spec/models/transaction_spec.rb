require "rails_helper"

RSpec.describe Transaction, type: :model do
  it "rejects account and credit card together on non-transfer" do
    transaction = build(:transaction, account: create(:account), credit_card: create(:credit_card, user: create(:user)))

    expect(transaction).not_to be_valid
    expect(transaction.errors.full_messages).to include("Use conta ou cartão, nunca ambos")
  end

  it "requires a destination account for transfers" do
    transaction = build(:transaction, :transfer, transfer_account: nil)

    expect(transaction).not_to be_valid
    expect(transaction.errors[:transfer_account]).to include("é obrigatória")
  end
end
