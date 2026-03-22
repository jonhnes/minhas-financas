require "rails_helper"

RSpec.describe CardHolder, type: :model do
  it { is_expected.to belong_to(:credit_card) }
  it { is_expected.to validate_presence_of(:name) }
  it do
    is_expected.to define_enum_for(:holder_type)
      .with_values(owner: "owner", additional: "additional")
      .backed_by_column_of_type(:string)
  end
end
