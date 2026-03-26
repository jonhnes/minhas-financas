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
end
