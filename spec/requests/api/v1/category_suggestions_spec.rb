require "rails_helper"

RSpec.describe "API category suggestions", type: :request do
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

  it "returns category suggestions with the expected contract" do
    user = create(:user)
    category = create(:category, user: user, name: "Assinaturas")
    account = create(:account, user: user)
    create(:transaction,
      user: user,
      account: account,
      category: category,
      canonical_merchant_name: "NETFLIX.COM",
      description: "Netflix")

    post "/api/v1/category_suggestions",
      params: {
        entries: [
          {
            entry_key: "entry-1",
            canonical_merchant_name: "NETFLIX.COM",
            description: "Netflix março"
          }
        ]
      }.to_json,
      headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    payload = response.parsed_body.fetch("data").first

    expect(payload.fetch("entry_key")).to eq("entry-1")
    expect(payload.fetch("suggestions").first).to include(
      "category_id" => category.id,
      "category_name" => "Assinaturas",
      "source" => "history",
      "match_type" => "exact",
      "matched_text" => "NETFLIX.COM"
    )
    expect(payload.fetch("suggestions").first.fetch("confidence")).to be_a(Float)
  end

  it "does not leak suggestions from another user" do
    owner = create(:user)
    stranger = create(:user)
    category = create(:category, user: owner, name: "Mercado")
    account = create(:account, user: owner)
    create(:transaction,
      user: owner,
      account: account,
      category: category,
      canonical_merchant_name: "SUPERMERCADO CENTRAL",
      description: "Mercado")

    post "/api/v1/category_suggestions",
      params: {
        entries: [
          {
            entry_key: "entry-1",
            canonical_merchant_name: "SUPERMERCADO CENTRAL"
          }
        ]
      }.to_json,
      headers: auth_headers_for(stranger)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data")).to eq([
      {
        "entry_key" => "entry-1",
        "suggestions" => []
      }
    ])
  end
end
