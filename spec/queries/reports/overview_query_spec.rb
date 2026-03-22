require "rails_helper"

RSpec.describe Reports::OverviewQuery do
  it "does not mix credit card purchases into consolidated cash balance" do
    user = create(:user)
    account = create(:account, user: user, initial_balance_cents: 200_000)
    card = create(:credit_card, user: user, payment_account: account)
    category = create(:category, user: user)
    create(:transaction, :income, user: user, account: account, category: category, amount_cents: 50_000, occurred_on: Date.new(2026, 3, 5))
    create(:transaction, user: user, account: account, category: category, amount_cents: 20_000, occurred_on: Date.new(2026, 3, 6))
    create(:transaction, :credit_card_purchase, user: user, credit_card: card, category: category, amount_cents: 15_000, occurred_on: Date.new(2026, 3, 7))

    result = described_class.new(user: user, params: ActionController::Parameters.new(month: "2026-03")).call

    expect(result[:consolidated_balance_cents]).to eq(230_000)
    expect(result[:monthly_expense_cents]).to eq(35_000)
    expect(result[:open_card_cycle_cents]).to eq(15_000)
  end

  it "excludes third_party expenses from consolidated balance by default" do
    user = create(:user)
    account = create(:account, user: user, initial_balance_cents: 500_000)
    category = create(:category, user: user)

    create(:transaction, user: user, account: account, category: category, amount_cents: 15_090, occurred_on: Date.new(2026, 3, 22))
    create(:transaction, user: user, account: account, category: category, amount_cents: 9_999, impact_mode: "third_party", occurred_on: Date.new(2026, 3, 22))

    result = described_class.new(user: user, params: ActionController::Parameters.new(month: "2026-03")).call

    expect(result[:consolidated_balance_cents]).to eq(484_910)
    expect(result[:monthly_expense_cents]).to eq(15_090)
  end
end
