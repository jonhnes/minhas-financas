require "rails_helper"

RSpec.describe User, type: :model do
  it { is_expected.to validate_presence_of(:name) }

  describe "defaults" do
    it "fills timezone and locale before validation" do
      user = described_class.new(name: "Teste", email: "teste@example.com", password: "password123", password_confirmation: "password123")

      user.validate

      expect(user.timezone).to eq("America/Sao_Paulo")
      expect(user.locale).to eq("pt-BR")
      expect(user.ui_preferences).to eq({})
    end
  end

  describe ".sanitize_ui_preferences_patch" do
    it "normalizes the transactions table preferences" do
      sanitized = described_class.sanitize_ui_preferences_patch(
        {
          transactions_table: {
            column_order: %w[amount description invalid amount],
            sort: {
              key: "source_name",
              direction: "asc"
            },
            impact_mode: "third_party"
          },
          dashboard: {
            hidden: true
          }
        }
      )

      expect(sanitized).to eq(
        {
          "transactions_table" => {
            "column_order" => %w[amount description impact date category source],
            "sort" => {
              "key" => "source_name",
              "direction" => "asc"
            },
            "impact_mode" => "third_party"
          }
        }
      )
    end

    it "falls back to safe defaults for invalid values" do
      sanitized = described_class.sanitize_ui_preferences_patch(
        {
          transactions_table: {
            column_order: ["unknown"],
            sort: {
              key: "invalid",
              direction: "sideways"
            },
            impact_mode: "invalid"
          }
        }
      )

      expect(sanitized).to eq(
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

  describe "#merged_ui_preferences" do
    it "deep merges sanitized transactions table preferences with the existing blob" do
      user = described_class.new(
        name: "Teste",
        email: "teste@example.com",
        password: "password123",
        password_confirmation: "password123",
        ui_preferences: {
          "dashboard" => {
            "collapsed" => true
          },
          "transactions_table" => {
            "impact_mode" => "all"
          }
        }
      )

      merged = user.merged_ui_preferences(
        {
          transactions_table: {
            column_order: %w[amount impact],
            sort: {
              key: "amount_cents",
              direction: "desc"
            }
          }
        }
      )

      expect(merged).to eq(
        {
          "dashboard" => {
            "collapsed" => true
          },
          "transactions_table" => {
            "impact_mode" => "all",
            "column_order" => %w[amount impact date description category source],
            "sort" => {
              "key" => "amount_cents",
              "direction" => "desc"
            }
          }
        }
      )
    end
  end
end
