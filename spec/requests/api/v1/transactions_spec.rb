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
end
