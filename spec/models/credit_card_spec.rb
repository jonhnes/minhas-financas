require "rails_helper"

RSpec.describe CreditCard, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_inclusion_of(:closing_day).in_range(1..31) }
  it { is_expected.to validate_inclusion_of(:due_day).in_range(1..31) }

  it "normalizes the last four digits before validation" do
    card = build(:credit_card, last_four_digits: "final 3468")

    card.validate

    expect(card.last_four_digits).to eq("3468")
  end
end
