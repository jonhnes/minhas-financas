require "rails_helper"

RSpec.describe "API transactions", type: :request do
  it "creates a transaction and reflects it in the overview" do
    user = create(:user)
    account = create(:account, user: user)
    category = create(:category, user: user)

    sign_in user

    get "/api/v1/auth/csrf", as: :json
    token = response.parsed_body.dig("data", "csrf_token")

    post "/api/v1/transactions",
      params: {
        transaction: {
          account_id: account.id,
          category_id: category.id,
          transaction_type: "expense",
          impact_mode: "normal",
          amount_cents: 12_500,
          occurred_on: "2026-03-22",
          description: "Mercado do mês",
          tag_ids: []
        }
      }.to_json,
      headers: {
        "ACCEPT" => "application/json",
        "CONTENT_TYPE" => "application/json",
        "X-CSRF-Token" => token
      }

    expect(response).to have_http_status(:created)

    get "/api/v1/reports/overview?month=2026-03", as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "monthly_expense_cents")).to eq(12_500)
  end

  it "optionally excludes third party transactions while preserving informational entries and ordering" do
    user = create(:user)
    account = create(:account, user: user)
    category = create(:category, user: user, name: "Compras")

    future_normal = create(
      :transaction,
      user: user,
      account: account,
      category: category,
      impact_mode: "normal",
      description: "Futuro",
      occurred_on: Date.new(2026, 3, 28)
    )
    third_party = create(
      :transaction,
      :third_party,
      user: user,
      account: account,
      category: category,
      description: "Terceiros",
      occurred_on: Date.new(2026, 3, 25)
    )
    informational = create(
      :transaction,
      user: user,
      account: account,
      category: category,
      impact_mode: "informational",
      description: "Informativo",
      occurred_on: Date.new(2026, 3, 24)
    )
    normal = create(
      :transaction,
      user: user,
      account: account,
      category: category,
      impact_mode: "normal",
      description: "Normal",
      occurred_on: Date.new(2026, 3, 23)
    )

    sign_in user

    get "/api/v1/transactions", params: { occurred_to: "2026-03-25" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).to eq([third_party.id, informational.id, normal.id])
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("impact_mode") }).to include("third_party", "informational")
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).not_to include(future_normal.id)

    get "/api/v1/transactions", params: { occurred_to: "2026-03-25", exclude_third_party: true }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).to eq([informational.id, normal.id])
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("impact_mode") }).to include("informational")
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("impact_mode") }).not_to include("third_party")
  end

  it "keeps the default chronological ordering when no sort params are provided" do
    user = create(:user)
    account = create(:account, user: user)
    alpha = create(:category, user: user, name: "Alpha")
    zulu = create(:category, user: user, name: "Zulu")
    beta = create(:category, user: user, name: "Beta")

    oldest = create(:transaction, user: user, account: account, category: alpha, description: "Mais antiga", occurred_on: Date.new(2026, 3, 3))
    newest = create(:transaction, user: user, account: account, category: zulu, description: "Mais recente", occurred_on: Date.new(2026, 3, 25))
    middle = create(:transaction, user: user, account: account, category: beta, description: "Intermediária", occurred_on: Date.new(2026, 3, 14))

    sign_in user

    get "/api/v1/transactions", as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).to eq([newest.id, middle.id, oldest.id])
  end

  it "orders transactions by category name ascending with chronological tie breakers" do
    user = create(:user)
    account = create(:account, user: user)
    alpha = create(:category, user: user, name: "Alpha")
    zulu = create(:category, user: user, name: "Zulu")
    beta = create(:category, user: user, name: "Beta")

    alpha_transaction = create(:transaction, user: user, account: account, category: alpha, description: "Categoria alpha", occurred_on: Date.new(2026, 3, 3))
    beta_transaction = create(:transaction, user: user, account: account, category: beta, description: "Categoria beta", occurred_on: Date.new(2026, 3, 14))
    zulu_transaction = create(:transaction, user: user, account: account, category: zulu, description: "Categoria zulu", occurred_on: Date.new(2026, 3, 25))

    sign_in user

    get "/api/v1/transactions", params: { sort_by: "category_name", sort_direction: "asc" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).to eq([alpha_transaction.id, beta_transaction.id, zulu_transaction.id])
  end

  it "orders transactions by category name descending" do
    user = create(:user)
    account = create(:account, user: user)
    alpha = create(:category, user: user, name: "Alpha")
    zulu = create(:category, user: user, name: "Zulu")
    beta = create(:category, user: user, name: "Beta")

    alpha_transaction = create(:transaction, user: user, account: account, category: alpha, description: "Categoria alpha", occurred_on: Date.new(2026, 3, 3))
    beta_transaction = create(:transaction, user: user, account: account, category: beta, description: "Categoria beta", occurred_on: Date.new(2026, 3, 14))
    zulu_transaction = create(:transaction, user: user, account: account, category: zulu, description: "Categoria zulu", occurred_on: Date.new(2026, 3, 25))

    sign_in user

    get "/api/v1/transactions", params: { sort_by: "category_name", sort_direction: "desc" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).to eq([zulu_transaction.id, beta_transaction.id, alpha_transaction.id])
  end

  it "orders transactions by description ascending" do
    user = create(:user)
    account = create(:account, user: user)
    category = create(:category, user: user, name: "Compras")

    zulu = create(:transaction, user: user, account: account, category: category, description: "Zulu", occurred_on: Date.new(2026, 3, 25))
    alpha = create(:transaction, user: user, account: account, category: category, description: "Alpha", occurred_on: Date.new(2026, 3, 3))
    beta = create(:transaction, user: user, account: account, category: category, description: "Beta", occurred_on: Date.new(2026, 3, 14))

    sign_in user

    get "/api/v1/transactions", params: { sort_by: "description", sort_direction: "asc" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).to eq([alpha.id, beta.id, zulu.id])
  end

  it "orders transactions by source name ascending across accounts and cards" do
    user = create(:user)
    alpha_account = create(:account, user: user, name: "Alpha Conta")
    zulu_account = create(:account, user: user, name: "Zulu Conta")
    beta_card = create(:credit_card, user: user, name: "Beta Card")
    category = create(:category, user: user, name: "Compras")

    zulu_transaction = create(:transaction, user: user, account: zulu_account, category: category, description: "Conta zulu", occurred_on: Date.new(2026, 3, 25))
    alpha_transaction = create(:transaction, user: user, account: alpha_account, category: category, description: "Conta alpha", occurred_on: Date.new(2026, 3, 3))
    beta_transaction = create(:transaction, :credit_card_purchase, user: user, credit_card: beta_card, category: category, description: "Cartão beta", occurred_on: Date.new(2026, 3, 14))

    sign_in user

    get "/api/v1/transactions", params: { sort_by: "source_name", sort_direction: "asc" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).to eq([alpha_transaction.id, beta_transaction.id, zulu_transaction.id])
  end

  it "orders transactions by amount ascending" do
    user = create(:user)
    account = create(:account, user: user)
    category = create(:category, user: user, name: "Compras")

    highest = create(:transaction, user: user, account: account, category: category, amount_cents: 25_00, description: "Maior", occurred_on: Date.new(2026, 3, 25))
    lowest = create(:transaction, user: user, account: account, category: category, amount_cents: 5_00, description: "Menor", occurred_on: Date.new(2026, 3, 3))
    middle = create(:transaction, user: user, account: account, category: category, amount_cents: 14_00, description: "Meio", occurred_on: Date.new(2026, 3, 14))

    sign_in user

    get "/api/v1/transactions", params: { sort_by: "amount_cents", sort_direction: "asc" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).to eq([lowest.id, middle.id, highest.id])
  end
end
