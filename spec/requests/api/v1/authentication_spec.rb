require "rails_helper"

RSpec.describe "API authentication", type: :request do
  it "signs up with CSRF token and returns the current user" do
    get "/api/v1/auth/csrf", as: :json

    token = response.parsed_body.dig("data", "csrf_token")

    post "/api/v1/auth/sign_up",
      params: {
        user: {
          name: "Jonhnes",
          email: "jonhnes@example.com",
          password: "password123",
          password_confirmation: "password123",
          timezone: "America/Sao_Paulo",
          locale: "pt-BR"
        }
      }.to_json,
      headers: {
        "ACCEPT" => "application/json",
        "CONTENT_TYPE" => "application/json",
        "X-CSRF-Token" => token
      }

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "email")).to eq("jonhnes@example.com")

    get "/api/v1/me", as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "name")).to eq("Jonhnes")
  end
end
