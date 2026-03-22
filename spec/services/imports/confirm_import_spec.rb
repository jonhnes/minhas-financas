require "rails_helper"

RSpec.describe Imports::ConfirmImport do
  it "creates a statement and the reviewed transactions" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    holder = create(:card_holder, credit_card: credit_card, name: "Jonhnes Lopes Menezes")
    import_record = create(:import, user: user, credit_card: credit_card)
    reviewed_item = create(:import_item, import: import_record, category: category, card_holder: holder, line_index: 1)
    ignored_item = create(:import_item, import: import_record, category: nil, ignored: true, description: "Pagamento", amount_cents: -5_000, line_index: 2)

    statement = described_class.new(import: import_record).call

    expect(statement).to be_persisted
    expect(import_record.reload).to be_confirmed
    expect(import_record.statement).to eq(statement)
    expect(import_record.import_items.pluck(:status).uniq).to eq(["imported"])
    expect(statement.transactions.count).to eq(1)
    expect(statement.transactions.first.import_item_id).to eq(reviewed_item.id)
    expect(ignored_item.reload.linked_transaction_id).to be_nil
  end

  it "rejects a duplicate statement period for the same card" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    import_record = create(:import, user: user, credit_card: credit_card)
    create(:import_item, import: import_record, category: category)
    create(:statement, credit_card: credit_card, period_start: Date.new(2026, 1, 29), period_end: Date.new(2026, 2, 28), due_date: Date.new(2026, 3, 5))

    expect { described_class.new(import: import_record).call }.to raise_error(Imports::ConfirmImport::InvalidImportError, /Já existe uma fatura/)
  end
end
