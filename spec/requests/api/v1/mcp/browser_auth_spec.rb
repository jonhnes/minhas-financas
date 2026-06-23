require "rails_helper"

RSpec.describe "API MCP browser auth", type: :request do
  def csrf_headers
    get "/api/v1/auth/csrf", as: :json
    {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json",
      "X-CSRF-Token" => response.parsed_body.dig("data", "csrf_token")
    }
  end

  def json_headers
    {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json"
    }
  end

  it "creates a local browser auth grant for the signed-in user" do
    user = create(:user)
    sign_in user

    post "/api/v1/mcp/browser_auth/authorizations",
      params: {
        authorization: {
          callback_url: "http://127.0.0.1:4567/callback",
          state: "state-123",
          device_label: "Codex MCP"
        }
      }.to_json,
      headers: csrf_headers

    expect(response).to have_http_status(:created)
    redirect_url = response.parsed_body.dig("data", "redirect_url")
    expect(redirect_url).to start_with("http://127.0.0.1:4567/callback?")
    expect(redirect_url).to include("state=state-123")
    expect(redirect_url).to include("code=")

    grant = McpBrowserAuthGrant.sole
    expect(grant.user).to eq(user)
    expect(grant.device_label).to eq("Codex MCP")
    expect(grant.code_digest).not_to be_empty
    expect(redirect_url).not_to include(grant.code_digest)
  end

  it "rejects non-local callback URLs" do
    user = create(:user)
    sign_in user

    post "/api/v1/mcp/browser_auth/authorizations",
      params: {
        authorization: {
          callback_url: "https://example.com/callback",
          state: "state-123"
        }
      }.to_json,
      headers: csrf_headers

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch("errors").join(" ")).to match(/localhost/i)
  end

  it "exchanges a valid code for mobile tokens once" do
    user = create(:user)
    _grant, code = McpBrowserAuthGrant.issue_for!(
      user: user,
      callback_url: "http://localhost:4321/callback",
      device_label: "Codex MCP"
    )

    post "/api/v1/mcp/browser_auth/token",
      params: {
        authorization: {
          code: code
        }
      }.to_json,
      headers: json_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "access_token")).to be_present
    expect(response.parsed_body.dig("data", "refresh_token")).to be_present
    expect(response.parsed_body.dig("data", "user", "email")).to eq(user.email)
    expect(MobileSession.last.platform).to eq("mcp")

    post "/api/v1/mcp/browser_auth/token",
      params: {
        authorization: {
          code: code
        }
      }.to_json,
      headers: json_headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects expired or invalid codes" do
    user = create(:user)
    _grant, code = McpBrowserAuthGrant.issue_for!(
      user: user,
      callback_url: "http://[::1]:4321/callback",
      device_label: "Codex MCP"
    )
    McpBrowserAuthGrant.last.update!(expires_at: 1.minute.ago)

    post "/api/v1/mcp/browser_auth/token",
      params: {
        authorization: {
          code: code
        }
      }.to_json,
      headers: json_headers

    expect(response).to have_http_status(:unauthorized)

    post "/api/v1/mcp/browser_auth/token",
      params: {
        authorization: {
          code: "invalid"
        }
      }.to_json,
      headers: json_headers

    expect(response).to have_http_status(:unauthorized)
  end
end
