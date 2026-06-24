require "rails_helper"

RSpec.describe FinancialResets::ResetTransactions do
  it "returns a backup and leaves data untouched in dry run" do
    user = create(:user)
    account = create(:account, user: user, initial_balance_cents: 123_45)
    credit_card = create(:credit_card, user: user)
    category = create(:category, user: user)
    tag = create(:tag, user: user)
    statement = create(:statement, credit_card: credit_card)
    import = create(:import, user: user, credit_card: credit_card, statement: statement, status: "confirmed")
    import_item = create(:import_item, import: import, category: category)
    transaction = create(:transaction, :credit_card_purchase, user: user, credit_card: credit_card, category: category, statement: statement, import_item: import_item)
    import_item.update!(linked_transaction: transaction)
    transaction.tags << tag

    result = described_class.new(user: user, dry_run: true).call

    expect(result[:dry_run]).to be(true)
    expect(result[:deleted]).to be(false)
    expect(result[:before]).to include(transactions: 1, imports: 1, import_items: 1, statements: 1)
    expect(result[:after]).to include(transactions: 1, imports: 1, import_items: 1, statements: 1)
    expect(result[:backup][:transactions].size).to eq(1)
    expect(account.reload.initial_balance_cents).to eq(123_45)
    expect(Transaction.exists?(transaction.id)).to be(true)
    expect(Import.exists?(import.id)).to be(true)
    expect(Statement.exists?(statement.id)).to be(true)
  end

  it "requires confirmation for destructive execution" do
    user = create(:user)

    expect do
      described_class.new(user: user, dry_run: false, confirmed: false).call
    end.to raise_error(FinancialResets::ResetTransactions::ConfirmationRequiredError)
  end

  it "deletes only financial history and zeros account balances when confirmed" do
    user = create(:user)
    other_user = create(:user)
    account = create(:account, user: user, initial_balance_cents: 123_45)
    other_account = create(:account, user: other_user, initial_balance_cents: 999_99)
    credit_card = create(:credit_card, user: user)
    category = create(:category, user: user)
    tag = create(:tag, user: user)
    statement = create(:statement, credit_card: credit_card)
    import = create(:import, user: user, credit_card: credit_card, statement: statement, status: "confirmed")
    import_item = create(:import_item, import: import, category: category)
    transaction = create(:transaction, :credit_card_purchase, user: user, credit_card: credit_card, category: category, statement: statement, import_item: import_item)
    import_item.update!(linked_transaction: transaction)
    transaction.tags << tag
    create(:transaction, user: other_user, account: other_account)

    result = described_class.new(user: user, dry_run: false, confirmed: true).call

    expect(result[:deleted]).to be(true)
    expect(user.transactions).to be_empty
    expect(user.imports).to be_empty
    expect(ImportItem.where(import_id: import.id)).to be_empty
    expect(Statement.where(id: statement.id)).to be_empty
    expect(account.reload.initial_balance_cents).to eq(0)
    expect(Category.where(id: category.id)).to exist
    expect(Tag.where(id: tag.id)).to exist
    expect(other_user.transactions.count).to eq(1)
    expect(other_account.reload.initial_balance_cents).to eq(999_99)
  end
end
