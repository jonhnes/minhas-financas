require "rails_helper"

RSpec.describe RecurringRule, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:description) }
  it do
    is_expected.to define_enum_for(:frequency)
      .with_values(weekly: "weekly", biweekly: "biweekly", monthly: "monthly", yearly: "yearly")
      .backed_by_column_of_type(:string)
  end
end
