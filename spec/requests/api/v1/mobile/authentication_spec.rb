require "rails_helper"

RSpec.describe "API mobile authentication", type: :request do
  def json_headers(token = nil)
    headers = {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json"
    }
    headers["Authorization"] = "Bearer #{token}" if token.present?
    headers
  end

  it "signs up and authenticates with bearer token" do
    post "/api/v1/mobile/auth/sign_up",
      params: {
        user: {
          name: "Jonhnes",
          email: "jonhnes@example.com",
          password: "password123",
          password_confirmation: "password123",
          timezone: "America/Sao_Paulo",
          locale: "pt-BR"
        },
        device: {
          platform: "ios",
          device_label: "iPhone 16"
        }
      }.to_json,
      headers: json_headers

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "user", "email")).to eq("jonhnes@example.com")
    expect(response.parsed_body.dig("data", "access_token")).to be_present
    expect(response.parsed_body.dig("data", "refresh_token")).to be_present

    get "/api/v1/me", headers: json_headers(response.parsed_body.dig("data", "access_token"))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "onboarding", "has_account")).to eq(false)
  end

  it "signs in, refreshes tokens, and signs out" do
    user = create(:user, email: "mobile@example.com", password: "password123", password_confirmation: "password123")

    post "/api/v1/mobile/auth/sign_in",
      params: {
        auth: {
          email: user.email,
          password: "password123",
          platform: "android",
          device_label: "Pixel"
        }
      }.to_json,
      headers: json_headers

    expect(response).to have_http_status(:ok)
    original_access_token = response.parsed_body.dig("data", "access_token")
    original_refresh_token = response.parsed_body.dig("data", "refresh_token")

    post "/api/v1/mobile/auth/refresh",
      params: {
        auth: {
          refresh_token: original_refresh_token
        }
      }.to_json,
      headers: json_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "access_token")).not_to eq(original_access_token)
    expect(response.parsed_body.dig("data", "refresh_token")).not_to eq(original_refresh_token)

    delete "/api/v1/mobile/auth/sign_out", headers: json_headers(response.parsed_body.dig("data", "access_token"))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "signed_out")).to eq(true)
  end

  it "rejects an expired or invalid refresh token" do
    post "/api/v1/mobile/auth/refresh",
      params: {
        auth: {
          refresh_token: "invalid"
        }
      }.to_json,
      headers: json_headers

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.fetch("errors").join(" ")).to match(/refresh token inválido ou expirado/i)
  end
end
