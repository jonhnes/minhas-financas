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

  it "returns category breakdown accumulated by default and filtered when month is provided" do
    user = create(:user)
    account = create(:account, user: user)
    transfer_account = create(:account, user: user, name: "Poupança")
    irrelevant_category = create(:category, user: user, name: "Irrelevante")
    travel_category = create(:category, user: user, name: "Passagens")

    create(
      :transaction,
      user: user,
      account: account,
      category: irrelevant_category,
      transaction_type: "expense",
      impact_mode: "normal",
      amount_cents: 20_000,
      occurred_on: Date.new(2026, 3, 20),
      description: "Despesa março"
    )
    create(
      :transaction,
      user: user,
      account: account,
      category: irrelevant_category,
      transaction_type: "expense",
      impact_mode: "normal",
      amount_cents: 10_000,
      occurred_on: Date.new(2026, 4, 5),
      description: "Despesa abril"
    )
    create(
      :transaction,
      user: user,
      account: account,
      category: travel_category,
      transaction_type: "expense",
      impact_mode: "normal",
      amount_cents: 5_000,
      occurred_on: Date.new(2026, 4, 9),
      description: "Passagem abril"
    )
    create(
      :transaction,
      :third_party,
      user: user,
      account: account,
      category: irrelevant_category,
      amount_cents: 90_000,
      occurred_on: Date.new(2026, 4, 12),
      description: "Terceiro abril"
    )
    create(
      :transaction,
      user: user,
      account: account,
      category: travel_category,
      transaction_type: "expense",
      impact_mode: "informational",
      amount_cents: 70_000,
      occurred_on: Date.new(2026, 4, 14),
      description: "Informacional abril"
    )
    create(
      :transaction,
      :transfer,
      user: user,
      account: account,
      transfer_account: transfer_account,
      amount_cents: 33_300,
      occurred_on: Date.new(2026, 4, 18),
      description: "Transferência abril"
    )

    sign_in user

    get "/api/v1/reports/category_breakdown", as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data")).to eq(
      [
        { "category_name" => "Irrelevante", "amount_cents" => 30_000, "transactions_count" => 2 },
        { "category_name" => "Passagens", "amount_cents" => 5_000, "transactions_count" => 1 }
      ]
    )

    get "/api/v1/reports/category_breakdown", params: { month: "2026-04" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data")).to eq(
      [
        { "category_name" => "Irrelevante", "amount_cents" => 10_000, "transactions_count" => 1 },
        { "category_name" => "Passagens", "amount_cents" => 5_000, "transactions_count" => 1 }
      ]
    )
  end

  it "returns a tenant-scoped spending distribution with stable category identifiers" do
    user = create(:user)
    other_user = create(:user)
    account = create(:account, user: user)
    other_account = create(:account, user: other_user)
    first_category = create(:category, user: user, name: "Duplicada")
    second_category = create(:category, user: user, name: "Duplicada")
    other_category = create(:category, user: other_user, name: "Duplicada")

    create(:transaction, user: user, account: account, category: first_category, amount_cents: 15_000, occurred_on: Date.new(2026, 7, 3))
    create(:transaction, user: user, account: account, category: second_category, amount_cents: 9_000, occurred_on: Date.new(2026, 7, 4))
    create(:transaction, user: other_user, account: other_account, category: other_category, amount_cents: 99_000, occurred_on: Date.new(2026, 7, 5))

    sign_in user

    allow(Time.zone).to receive(:today).and_return(Date.new(2026, 8, 1))

    get "/api/v1/reports/spending_distribution", params: { month: "2026-07" }, as: :json

    expect(response).to have_http_status(:ok)
    data = response.parsed_body.fetch("data")
    expect(data).to include(
      "total_amount_cents" => 24_000,
      "transactions_count" => 2,
      "period" => { "from" => "2026-07-01", "to" => "2026-07-31", "partial" => false }
    )
    expect(data.fetch("categories").map { |entry| entry.fetch("category_id") }).to contain_exactly(first_category.id, second_category.id)
    expect(data.fetch("categories").map { |entry| entry.fetch("key") }).to contain_exactly("category:#{first_category.id}", "category:#{second_category.id}")
  end

  it "requires authentication for spending distribution" do
    get "/api/v1/reports/spending_distribution", params: { month: "2026-07" }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
