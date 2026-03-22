require "rails_helper"

RSpec.describe Import, type: :model do
  it "is valid with an attached PDF" do
    expect(build(:import)).to be_valid
  end

  it "requires a source file" do
    import_record = build(:import)
    import_record.source_file.detach

    expect(import_record).not_to be_valid
    expect(import_record.errors[:source_file]).to include("é obrigatório")
  end

  it "knows when it can be confirmed" do
    import_record = build(:import, status: "review_pending", statement: nil, confirmed_at: nil)

    expect(import_record.confirmable?).to be(true)
  end
end
