require "rails_helper"

RSpec.describe "API financial resets", type: :request do
  def csrf_headers
    get "/api/v1/auth/csrf", as: :json
    {
      "ACCEPT" => "application/json",
      "X-CSRF-Token" => response.parsed_body.dig("data", "csrf_token")
    }
  end

  it "runs a dry-run reset for the authenticated user" do
    user = create(:user)
    create(:transaction, user: user)

    sign_in user

    post "/api/v1/financial_resets/transactions",
      params: { reset: { dry_run: true } },
      headers: csrf_headers,
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "dry_run")).to be(true)
    expect(response.parsed_body.dig("data", "before", "transactions")).to eq(1)
    expect(user.transactions.count).to eq(1)
  end

  it "rejects destructive reset without confirmation" do
    user = create(:user)

    sign_in user

    post "/api/v1/financial_resets/transactions",
      params: { reset: { dry_run: false, confirmed: false } },
      headers: csrf_headers,
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "does not expose the reset action under the MCP namespace" do
    user = create(:user)

    sign_in user

    post "/api/v1/mcp/financial_resets/transactions",
      params: { reset: { dry_run: true } },
      headers: csrf_headers,
      as: :json

    expect(response).to have_http_status(:not_found)
  end
end
