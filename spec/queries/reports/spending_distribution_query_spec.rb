require "rails_helper"

RSpec.describe Reports::SpendingDistributionQuery do
  def query_for(user, params = {}, today: Date.new(2026, 8, 1), **filters)
    described_class.new(
      user: user,
      params: ActionController::Parameters.new({ month: "2026-07" }.merge(params).merge(filters)),
      categories_scope: Category.where("user_id = ? OR (user_id IS NULL AND system = ?)", user.id, true),
      today: today
    ).call
  end

  it "rolls subcategories into roots while retaining direct and uncategorized spending" do
    user = create(:user)
    account = create(:account, user: user)
    house = create(:category, user: user, name: "Casa")
    market = create(:category, user: user, parent: house, name: "Mercado")
    transport = create(:category, user: user, name: "Transporte")

    create(:transaction, user: user, account: account, category: house, amount_cents: 20_000, occurred_on: Date.new(2026, 7, 3))
    create(:transaction, user: user, account: account, category: market, amount_cents: 50_000, occurred_on: Date.new(2026, 7, 4))
    create(:transaction, user: user, account: account, category: market, amount_cents: 25_000, occurred_on: Date.new(2026, 6, 4))
    create(:transaction, user: user, account: account, category: transport, amount_cents: 12_000, occurred_on: Date.new(2026, 7, 5))
    uncategorized = create(:transaction, user: user, account: account, category: house, amount_cents: 5_000, occurred_on: Date.new(2026, 7, 6))
    uncategorized.update_column(:category_id, nil)

    result = query_for(user)
    house_entry = result.fetch(:categories).find { |entry| entry[:category_id] == house.id }
    market_entry = house_entry.fetch(:children).find { |entry| entry[:category_id] == market.id }
    uncategorized_entry = result.fetch(:categories).find { |entry| entry[:key] == "uncategorized" }

    expect(result).to include(total_amount_cents: 87_000, transactions_count: 4)
    expect(house_entry).to include(
      amount_cents: 70_000,
      transactions_count: 2,
      previous_amount_cents: 25_000,
      direct_amount_cents: 20_000,
      direct_transactions_count: 1
    )
    expect(market_entry).to include(amount_cents: 50_000, previous_amount_cents: 25_000)
    expect(uncategorized_entry).to include(amount_cents: 5_000, transactions_count: 1, name: "Sem categoria")
    expect(result.fetch(:categories).map { |entry| entry[:name] }).to eq([ "Casa", "Transporte", "Sem categoria" ])
  end

  it "shares source, tag, text and impact filters while exposing excluded modes" do
    user = create(:user)
    account = create(:account, user: user)
    other_account = create(:account, user: user)
    category = create(:category, user: user, name: "Alimentação")
    tag = create(:tag, user: user, name: "Casa")
    normal = create(:transaction, user: user, account: account, category: category, amount_cents: 15_000, description: "Padaria Central", occurred_on: Date.new(2026, 7, 2))
    normal.tags << tag
    third_party = create(:transaction, :third_party, user: user, account: account, category: category, amount_cents: 9_000, description: "Padaria reembolsável", occurred_on: Date.new(2026, 7, 3))
    third_party.tags << tag
    informational = create(:transaction, user: user, account: account, category: category, impact_mode: "informational", amount_cents: 7_000, description: "Padaria informativa", occurred_on: Date.new(2026, 7, 4))
    informational.tags << tag
    create(:transaction, user: user, account: other_account, category: category, amount_cents: 30_000, description: "Padaria outra conta", occurred_on: Date.new(2026, 7, 5))

    result = query_for(user, account_id: account.id, tag_id: tag.id, query: "Padaria")
    third_party_result = query_for(user, account_id: account.id, tag_id: tag.id, query: "Padaria", impact_mode: "third_party")

    expect(result).to include(total_amount_cents: 15_000, transactions_count: 1)
    expect(result.fetch(:excluded)).to eq(
      "third_party" => { amount_cents: 9_000, transactions_count: 1 },
      "informational" => { amount_cents: 7_000, transactions_count: 1 }
    )
    expect(third_party_result).to include(total_amount_cents: 9_000, transactions_count: 1)
  end

  it "uses a comparable elapsed-day window for the current month" do
    user = create(:user)
    account = create(:account, user: user)
    category = create(:category, user: user, name: "Saúde")

    create(:transaction, user: user, account: account, category: category, amount_cents: 20_000, occurred_on: Date.new(2026, 7, 18))
    create(:transaction, user: user, account: account, category: category, amount_cents: 30_000, occurred_on: Date.new(2026, 7, 19))
    create(:transaction, user: user, account: account, category: category, amount_cents: 10_000, occurred_on: Date.new(2026, 6, 18))
    create(:transaction, user: user, account: account, category: category, amount_cents: 40_000, occurred_on: Date.new(2026, 6, 19))

    result = query_for(user, {}, today: Date.new(2026, 7, 18))
    entry = result.fetch(:categories).first

    expect(result.fetch(:period)).to eq(from: "2026-07-01", to: "2026-07-18", partial: true)
    expect(result.fetch(:comparison_period)).to eq(from: "2026-06-01", to: "2026-06-18", partial: false)
    expect(entry).to include(amount_cents: 20_000, previous_amount_cents: 10_000)
  end
end
