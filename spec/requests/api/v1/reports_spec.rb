require "rails_helper"

RSpec.describe "API reports", type: :request do
  it "returns a six month monthly flow series without raising errors" do
    user = create(:user)
    account = create(:account, user: user)
    income_category = create(:category, user: user, name: "Salario")
    expense_category = create(:category, user: user, name: "Mercado")

    create(
      :transaction,
      user: user,
      account: account,
      category: income_category,
      transaction_type: "income",
      impact_mode: "normal",
      amount_cents: 500_000,
      occurred_on: Date.new(2026, 1, 15),
      description: "Salario janeiro"
    )
    create(
      :transaction,
      user: user,
      account: account,
      category: expense_category,
      transaction_type: "expense",
      impact_mode: "normal",
      amount_cents: 120_000,
      occurred_on: Date.new(2026, 2, 8),
      description: "Mercado fevereiro"
    )
    create(
      :transaction,
      user: user,
      account: account,
      category: income_category,
      transaction_type: "income",
      impact_mode: "normal",
      amount_cents: 650_000,
      occurred_on: Date.new(2026, 6, 3),
      description: "Salario junho"
    )

    sign_in user

    get "/api/v1/reports/monthly_flow", params: { month: "2026-06" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data")).to eq(
      [
        { "month" => "2026-01-01", "income_cents" => 500_000, "expense_cents" => 0 },
        { "month" => "2026-02-01", "income_cents" => 0, "expense_cents" => 120_000 },
        { "month" => "2026-03-01", "income_cents" => 0, "expense_cents" => 0 },
        { "month" => "2026-04-01", "income_cents" => 0, "expense_cents" => 0 },
        { "month" => "2026-05-01", "income_cents" => 0, "expense_cents" => 0 },
        { "month" => "2026-06-01", "income_cents" => 650_000, "expense_cents" => 0 }
      ]
    )
  end
end
