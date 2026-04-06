require "rails_helper"

RSpec.describe "API bearer access", type: :request do
  def bearer_headers(token)
    {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json",
      "Authorization" => "Bearer #{token}"
    }
  end

  it "allows bearer access across the main mobile resources" do
    user = create(:user)
    account = create(:account, user: user, name: "Conta principal")
    category = create(:category, user: user, name: "Mercado")
    card = create(:credit_card, user: user, payment_account: account, name: "Visa")
    create(:transaction, user: user, account: account, category: category, description: "Supermercado", occurred_on: Date.new(2026, 4, 5))
    issued = MobileSession.issue_for!(user: user, platform: "ios", device_label: "iPhone")

    get "/api/v1/me", headers: bearer_headers(issued.fetch(:access_token))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "email")).to eq(user.email)

    get "/api/v1/transactions", headers: bearer_headers(issued.fetch(:access_token))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", 0, "description")).to eq("Supermercado")

    get "/api/v1/credit_cards", headers: bearer_headers(issued.fetch(:access_token))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", 0, "name")).to eq(card.name)

    get "/api/v1/reports/overview", headers: bearer_headers(issued.fetch(:access_token))
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to have_key("data")
  end

  it "returns unauthorized without a valid bearer token or session" do
    get "/api/v1/me", headers: { "ACCEPT" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.fetch("errors")).to include("Não autorizado")
  end
end
