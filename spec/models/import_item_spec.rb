require "rails_helper"

RSpec.describe ImportItem, type: :model do
  it "is valid with a category" do
    expect(build(:import_item)).to be_valid
  end

  it "requires category confirmation for active items" do
    import_item = build(:import_item, category: nil, ignored: false)

    expect(import_item.needs_category?).to be(true)
  end

  it "does not require category when ignored" do
    import_item = build(:import_item, category: nil, ignored: true)

    expect(import_item.needs_category?).to be(false)
  end
end
