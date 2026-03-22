require "rails_helper"

RSpec.describe CreditCard, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_inclusion_of(:closing_day).in_range(1..31) }
  it { is_expected.to validate_inclusion_of(:due_day).in_range(1..31) }
end
