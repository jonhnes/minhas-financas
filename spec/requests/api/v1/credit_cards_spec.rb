require "rails_helper"

RSpec.describe "API credit cards", type: :request do
  def auth_headers_for(user)
    sign_in user

    get "/api/v1/auth/csrf", as: :json
    token = response.parsed_body.dig("data", "csrf_token")

    {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json",
      "X-CSRF-Token" => token
    }
  end

  it "creates a credit card normalizing and exposing the last four digits" do
    user = create(:user)
    account = create(:account, user: user)

    post "/api/v1/credit_cards",
      params: {
        credit_card: {
          payment_account_id: account.id,
          name: "Bradesco Visa",
          brand: "Visa",
          last_four_digits: "final 3468",
          credit_limit_cents: 120_000,
          closing_day: 5,
          due_day: 12
        }
      }.to_json,
      headers: auth_headers_for(user)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "last_four_digits")).to eq("3468")
    expect(user.credit_cards.last.last_four_digits).to eq("3468")
  end

  it "updates the last four digits" do
    user = create(:user)
    card = create(:credit_card, user: user, last_four_digits: nil)

    patch "/api/v1/credit_cards/#{card.id}",
      params: {
        credit_card: {
          last_four_digits: "3785"
        }
      }.to_json,
      headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(card.reload.last_four_digits).to eq("3785")
  end

  it "lists selectable credit cards without dashboard payload" do
    user = create(:user)
    stranger = create(:user)
    active_card = create(:credit_card, user: user, name: "Inter Black", brand: "Mastercard", active: true)
    inactive_card = create(:credit_card, user: user, name: "Bradesco Visa", brand: "Visa", active: false)
    create(:credit_card, user: stranger, name: "Cartão de fora", brand: "Elo")

    get "/api/v1/credit_cards/selectable", headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).not_to have_key("meta")
    expect(response.parsed_body.fetch("data")).to eq([
      {
        "id" => active_card.id,
        "name" => "Inter Black",
        "brand" => "Mastercard"
      },
      {
        "id" => inactive_card.id,
        "name" => "Bradesco Visa",
        "brand" => "Visa"
      }
    ])
  end
end
