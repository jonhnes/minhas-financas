require "rails_helper"

RSpec.describe Budget, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:category) }
  it { is_expected.to validate_inclusion_of(:period_type).in_array(["monthly"]) }
end
