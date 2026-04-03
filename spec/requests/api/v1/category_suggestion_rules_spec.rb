require "rails_helper"

RSpec.describe "API category suggestion rules", type: :request do
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

  it "creates, lists, updates and deletes a rule for the current user" do
    user = create(:user)
    groceries = create(:category, user: user, name: "Mercado")
    travel = create(:category, user: user, name: "Viagens")
    headers = auth_headers_for(user)

    post "/api/v1/category_suggestion_rules",
      params: {
        category_suggestion_rule: {
          category_id: groceries.id,
          match_type: "contains",
          pattern: "MERCADO",
          active: true,
          position: 3
        }
      }.to_json,
      headers: headers

    expect(response).to have_http_status(:created)
    rule_id = response.parsed_body.dig("data", "id")
    expect(response.parsed_body.dig("data", "normalized_pattern")).to eq("MERCADO")

    get "/api/v1/category_suggestion_rules?per_page=100", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |row| row.fetch("id") }).to include(rule_id)

    patch "/api/v1/category_suggestion_rules/#{rule_id}",
      params: {
        category_suggestion_rule: {
          category_id: travel.id,
          match_type: "starts_with",
          pattern: "HOTEL",
          active: false,
          position: 1
        }
      }.to_json,
      headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data")).to include(
      "category_id" => travel.id,
      "match_type" => "starts_with",
      "pattern" => "HOTEL",
      "normalized_pattern" => "HOTEL",
      "active" => false,
      "position" => 1
    )

    delete "/api/v1/category_suggestion_rules/#{rule_id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("data" => { "deleted" => true })
    expect(CategorySuggestionRule.exists?(rule_id)).to be(false)
  end

  it "returns not found when accessing another user's rule" do
    owner = create(:user)
    stranger = create(:user)
    rule = create(:category_suggestion_rule, user: owner)

    get "/api/v1/category_suggestion_rules/#{rule.id}", headers: auth_headers_for(stranger)

    expect(response).to have_http_status(:not_found)
  end
end
