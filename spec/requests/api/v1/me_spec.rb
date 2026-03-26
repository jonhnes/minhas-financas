require "rails_helper"

RSpec.describe "API me", type: :request do
  def csrf_token
    get "/api/v1/auth/csrf", as: :json
    response.parsed_body.dig("data", "csrf_token")
  end

  it "persists sanitized transactions table preferences and preserves other preference branches" do
    user = create(
      :user,
      ui_preferences: {
        "dashboard" => {
          "collapsed" => true
        }
      }
    )

    sign_in user

    patch "/api/v1/me",
      params: {
        me: {
          ui_preferences: {
            transactions_table: {
              column_order: %w[amount description invalid],
              sort: {
                key: "category_name",
                direction: "asc"
              },
              impact_mode: "third_party"
            },
            dashboard: {
              hidden: false
            }
          }
        }
      }.to_json,
      headers: {
        "ACCEPT" => "application/json",
        "CONTENT_TYPE" => "application/json",
        "X-CSRF-Token" => csrf_token
      }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "ui_preferences")).to eq(
      {
        "dashboard" => {
          "collapsed" => true
        },
        "transactions_table" => {
          "column_order" => %w[amount description impact date category source],
          "sort" => {
            "key" => "category_name",
            "direction" => "asc"
          },
          "impact_mode" => "third_party"
        }
      }
    )

    expect(user.reload.ui_preferences).to eq(
      {
        "dashboard" => {
          "collapsed" => true
        },
        "transactions_table" => {
          "column_order" => %w[amount description impact date category source],
          "sort" => {
            "key" => "category_name",
            "direction" => "asc"
          },
          "impact_mode" => "third_party"
        }
      }
    )
  end

  it "normalizes invalid transactions table values" do
    user = create(:user)

    sign_in user

    patch "/api/v1/me",
      params: {
        me: {
          ui_preferences: {
            transactions_table: {
              column_order: ["unknown"],
              sort: {
                key: "invalid",
                direction: "sideways"
              },
              impact_mode: "invalid"
            }
          }
        }
      }.to_json,
      headers: {
        "ACCEPT" => "application/json",
        "CONTENT_TYPE" => "application/json",
        "X-CSRF-Token" => csrf_token
      }

    expect(response).to have_http_status(:ok)
    expect(user.reload.ui_preferences).to eq(
      {
        "transactions_table" => {
          "column_order" => %w[impact date description category source amount],
          "sort" => {
            "key" => "occurred_on",
            "direction" => "desc"
          },
          "impact_mode" => "all"
        }
      }
    )
  end
end
