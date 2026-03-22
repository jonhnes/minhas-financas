require "rails_helper"

RSpec.describe "API imports", type: :request do
  def csrf_headers
    get "/api/v1/auth/csrf", as: :json
    {
      "ACCEPT" => "application/json",
      "X-CSRF-Token" => response.parsed_body.dig("data", "csrf_token")
    }
  end

  it "uploads a PDF and produces a reviewable import" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)

    sign_in user

    post "/api/v1/imports",
      params: {
        import: {
          credit_card_id: credit_card.id,
          provider_key: "inter_pdf",
          source_file: Rack::Test::UploadedFile.new(Rails.root.join("doc", "inter.pdf"), "application/pdf")
        }
      },
      headers: csrf_headers

    expect(response).to have_http_status(:created)

    import_record = Import.last
    expect(import_record).to be_review_pending
    expect(import_record.import_items.count).to be > 10
  end

  it "shows, edits and confirms a reviewed import" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    import_record = create(:import, user: user, credit_card: credit_card)
    import_item = create(:import_item, import: import_record, category: nil)

    sign_in user
    headers = csrf_headers

    get "/api/v1/imports/#{import_record.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "items", 0, "id")).to eq(import_item.id)

    patch "/api/v1/imports/#{import_record.id}",
      params: {
        import: {
          period_start: "2026-01-29",
          period_end: "2026-02-28",
          due_date: "2026-03-05",
          total_amount_cents: 649_417
        }
      }.to_json,
      headers: headers.merge("CONTENT_TYPE" => "application/json")

    expect(response).to have_http_status(:ok)
    expect(import_record.reload.statement_payload["due_date"]).to eq("2026-03-05")

    patch "/api/v1/import_items/#{import_item.id}",
      params: {
        import_item: {
          occurred_on: "2026-02-10",
          description: "Mercado revisado",
          amount_cents: 12_390,
          category_id: category.id,
          impact_mode: "normal",
          ignored: false
        }
      }.to_json,
      headers: headers.merge("CONTENT_TYPE" => "application/json")

    expect(response).to have_http_status(:ok)
    expect(import_item.reload.category_id).to eq(category.id)

    post "/api/v1/imports/#{import_record.id}/confirm", headers: headers

    expect(response).to have_http_status(:ok)
    expect(import_record.reload).to be_confirmed
    expect(import_record.statement).to be_present

    get "/api/v1/statements?credit_card_id=#{credit_card.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", 0, "id")).to eq(import_record.statement_id)
  end

  it "isolates imports by user" do
    owner = create(:user)
    stranger = create(:user)
    import_record = create(:import, user: owner)

    sign_in stranger

    get "/api/v1/imports/#{import_record.id}", headers: csrf_headers

    expect(response).to have_http_status(:not_found)
  end
end
