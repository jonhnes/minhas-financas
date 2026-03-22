require "rails_helper"

RSpec.describe Statement, type: :model do
  it "is valid with the factory defaults" do
    expect(build(:statement)).to be_valid
  end

  it "rejects an inverted period" do
    statement = build(:statement, period_start: Date.new(2026, 3, 10), period_end: Date.new(2026, 3, 2))

    expect(statement).not_to be_valid
    expect(statement.errors[:period_end]).to include("deve ser igual ou posterior ao início")
  end
end
