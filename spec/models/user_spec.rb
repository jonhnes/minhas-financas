require "rails_helper"

RSpec.describe User, type: :model do
  it { is_expected.to validate_presence_of(:name) }

  describe "defaults" do
    it "fills timezone and locale before validation" do
      user = described_class.new(name: "Teste", email: "teste@example.com", password: "password123", password_confirmation: "password123")

      user.validate

      expect(user.timezone).to eq("America/Sao_Paulo")
      expect(user.locale).to eq("pt-BR")
    end
  end
end
