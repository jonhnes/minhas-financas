require "rails_helper"

RSpec.describe CategorySuggestions::Resolver do
  it "prioritizes a starts_with rule over conflicting historical matches" do
    user = create(:user)
    travel = create(:category, user: user, name: "Viagens")
    groceries = create(:category, user: user, name: "Mercado")
    account = create(:account, user: user)
    create(:category_suggestion_rule, user: user, category: travel, match_type: "starts_with", pattern: "HOTEL", position: 1)
    create(:transaction,
      user: user,
      account: account,
      category: groceries,
      canonical_merchant_name: "HOTEL FAZENDA",
      description: "Hotel Fazenda")

    result = described_class.new(
      user: user,
      entries: [{ entry_key: "hotel", canonical_merchant_name: "HOTEL FAZENDA" }]
    ).call.first

    expect(result[:suggestions].first).to include(
      category_id: travel.id,
      category_name: "Viagens",
      source: "rule",
      match_type: "starts_with",
      matched_text: "HOTEL"
    )
  end

  it "prefers the most recent category when historical exact matches tie in frequency" do
    user = create(:user)
    transport = create(:category, user: user, name: "Transporte")
    misc = create(:category, user: user, name: "Diversos")
    account = create(:account, user: user)
    create(:transaction,
      user: user,
      account: account,
      category: transport,
      canonical_merchant_name: "UBER TRIP",
      description: "Uber viagem",
      occurred_on: Date.new(2026, 3, 10))
    create(:transaction,
      user: user,
      account: account,
      category: misc,
      canonical_merchant_name: "UBER TRIP",
      description: "Uber viagem",
      occurred_on: Date.new(2026, 3, 20))

    result = described_class.new(
      user: user,
      entries: [{ entry_key: "uber", canonical_merchant_name: "UBER TRIP" }]
    ).call.first

    expect(result[:suggestions].first).to include(
      category_id: misc.id,
      category_name: "Diversos",
      source: "history",
      match_type: "exact",
      matched_text: "UBER TRIP"
    )
  end

  it "returns no suggestions when neither rules nor history match" do
    user = create(:user)

    result = described_class.new(
      user: user,
      entries: [{ entry_key: "unknown", description: "Compra inédita" }]
    ).call.first

    expect(result).to eq(entry_key: "unknown", suggestions: [])
  end

  it "isolates suggestions by tenant" do
    owner = create(:user)
    stranger = create(:user)
    category = create(:category, user: owner, name: "Assinaturas")
    account = create(:account, user: owner)
    create(:transaction,
      user: owner,
      account: account,
      category: category,
      canonical_merchant_name: "NETFLIX.COM",
      description: "Netflix")

    result = described_class.new(
      user: stranger,
      entries: [{ entry_key: "netflix", canonical_merchant_name: "NETFLIX.COM" }]
    ).call.first

    expect(result).to eq(entry_key: "netflix", suggestions: [])
  end
end
