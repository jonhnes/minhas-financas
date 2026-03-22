require "rails_helper"

RSpec.describe "Api::V1::RecurringRules", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, :system_default) }

  before do
    sign_in user
  end

  describe "POST /api/v1/recurring_rules" do
    it "defaults active to true when omitted" do
      post "/api/v1/recurring_rules",
        params: {
          recurring_rule: {
            account_id: account.id,
            category_id: category.id,
            frequency: "monthly",
            transaction_type: "expense",
            impact_mode: "normal",
            amount_cents: 8_990,
            description: "Mercado mensal",
            starts_on: Date.current
          }
        },
        as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "active")).to eq(true)
      expect(user.recurring_rules.last).to be_active
    end
  end
end
