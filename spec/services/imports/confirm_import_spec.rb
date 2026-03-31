require "rails_helper"

RSpec.describe Imports::ConfirmImport do
  it "creates a statement and the reviewed transactions" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    holder = create(:card_holder, credit_card: credit_card, name: "Jonhnes Lopes Menezes")
    import_record = create(:import,
      user: user,
      credit_card: credit_card,
      parsed_payload: {
        "statement" => {
          "period_start" => "2026-03-01",
          "period_end" => "2026-03-31",
          "due_date" => "2026-04-05",
          "total_amount_cents" => 49_560,
          "status" => "open",
          "metadata" => {}
        },
        "summary" => {
          "total_items" => 2,
          "ignored_items" => 1,
          "reviewable_items" => 1
        }
      })
    installment_metadata = {
      "detected" => true,
      "current_number" => 2,
      "total_installments" => 5,
      "purchase_occurred_on" => "2026-02-10",
      "source_format" => "parenthesized_parcela"
    }
    installment_group_key = Installments::Support.group_key(
      credit_card_id: credit_card.id,
      canonical_merchant_name: "MERCADO DA IMPORTACAO",
      purchase_occurred_on: Date.new(2026, 2, 10),
      amount_cents: 12_390,
      installment_total: 5
    )
    reviewed_item = create(
      :import_item,
      import: import_record,
      category: category,
      card_holder: holder,
      line_index: 1,
      occurred_on: Date.new(2026, 3, 10),
      installment_detected: true,
      installment_enabled: true,
      installment_group_key: installment_group_key,
      installment_number: 2,
      installment_total: 5,
      purchase_occurred_on: Date.new(2026, 2, 10),
      metadata: {
        "provider_key" => "inter_pdf",
        "installment" => installment_metadata
      }
    )
    ignored_item = create(:import_item, import: import_record, category: nil, ignored: true, description: "Pagamento", amount_cents: -5_000, line_index: 2)

    statement = described_class.new(import: import_record).call
    current_transaction = statement.transactions.find_by(import_item_id: reviewed_item.id)
    future_transactions = user.transactions.where(installment_group_key: installment_group_key, auto_generated: true).order(:installment_number)

    expect(statement).to be_persisted
    expect(import_record.reload).to be_confirmed
    expect(import_record.statement).to eq(statement)
    expect(import_record.import_items.pluck(:status).uniq).to eq(["imported"])
    expect(statement.transactions.count).to eq(1)
    expect(current_transaction.import_item_id).to eq(reviewed_item.id)
    expect(current_transaction.occurred_on).to eq(Date.new(2026, 3, 10))
    expect(current_transaction.installment_group_key).to eq(installment_group_key)
    expect(current_transaction.installment_number).to eq(2)
    expect(current_transaction.installment_total).to eq(5)
    expect(current_transaction.purchase_occurred_on).to eq(Date.new(2026, 2, 10))
    expect(current_transaction.metadata["installment"]).to include(
      "current_number" => 2,
      "total_installments" => 5,
      "purchase_occurred_on" => "2026-02-10",
      "group_key" => installment_group_key
    )
    expect(future_transactions.pluck(:installment_number)).to eq([3, 4, 5])
    expect(future_transactions.pluck(:occurred_on)).to eq([
      Date.new(2026, 4, 10),
      Date.new(2026, 5, 10),
      Date.new(2026, 6, 10)
    ])
    expect(ignored_item.reload.linked_transaction_id).to be_nil
  end

  it "reconciles an auto-generated future installment when the next statement is imported" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    previous_import = create(:import, user: user, credit_card: credit_card, status: :confirmed, confirmed_at: Time.zone.parse("2026-03-22 12:00:00"))
    current_import = create(:import,
      user: user,
      credit_card: credit_card,
      parsed_payload: {
        "statement" => {
          "period_start" => "2026-04-01",
          "period_end" => "2026-04-30",
          "due_date" => "2026-05-05",
          "total_amount_cents" => 12_390,
          "status" => "open",
          "metadata" => {}
        },
        "summary" => {
          "total_items" => 1,
          "ignored_items" => 0,
          "reviewable_items" => 1
        }
      }
    )
    installment_group_key = Installments::Support.group_key(
      credit_card_id: credit_card.id,
      canonical_merchant_name: "MERCADO DA IMPORTACAO",
      purchase_occurred_on: Date.new(2026, 2, 10),
      amount_cents: 12_390,
      installment_total: 3
    )
    placeholder = create(:transaction,
      :credit_card_purchase,
      user: user,
      credit_card: credit_card,
      category: category,
      statement: nil,
      import_item: nil,
      auto_generated: true,
      description: "Mercado placeholder",
      notes: "ajuste do usuário",
      installment_group_key: installment_group_key,
      installment_number: 3,
      installment_total: 3,
      purchase_occurred_on: Date.new(2026, 2, 10),
      occurred_on: Date.new(2026, 4, 10),
      metadata: { "generated_from_import_id" => previous_import.id, "provider_key" => "inter_pdf" })
    tag = create(:tag, user: user, name: "Parcelado")
    placeholder.tags << tag
    import_item = create(:import_item,
      import: current_import,
      category: category,
      line_index: 1,
      description: "Mercado da importação",
      amount_cents: 12_390,
      occurred_on: Date.new(2026, 4, 10),
      installment_detected: true,
      installment_enabled: true,
      installment_group_key: installment_group_key,
      installment_number: 3,
      installment_total: 3,
      purchase_occurred_on: Date.new(2026, 2, 10),
      metadata: {
        "provider_key" => "inter_pdf",
        "installment" => {
          "detected" => true,
          "current_number" => 3,
          "total_installments" => 3,
          "purchase_occurred_on" => "2026-02-10",
          "source_format" => "parenthesized_parcela"
        }
      })

    statement = described_class.new(import: current_import).call

    expect(statement.transactions.count).to eq(1)
    expect(placeholder.reload.statement).to eq(statement)
    expect(placeholder.import_item).to eq(import_item)
    expect(placeholder.auto_generated).to be(false)
    expect(placeholder.notes).to eq("ajuste do usuário")
    expect(placeholder.tags.pluck(:id)).to eq([tag.id])
    expect(placeholder.description).to eq("Mercado da importação")
    expect(placeholder.metadata["import_id"]).to eq(current_import.id)
    expect(placeholder.metadata["provider_key"]).to eq("inter_pdf")
  end

  it "confirms a parcelado even when its theoretical occurrence falls outside the imported statement cycle" do
    user = create(:user)
    credit_card = create(:credit_card, user: user, closing_day: 28, due_day: 5)
    category = create(:category, user: user)
    import_record = create(:import,
      user: user,
      credit_card: credit_card,
      parsed_payload: {
        "statement" => {
          "period_start" => "2026-03-01",
          "period_end" => "2026-03-31",
          "due_date" => "2026-04-05",
          "total_amount_cents" => 12_390,
          "status" => "open",
          "metadata" => {}
        },
        "summary" => {
          "total_items" => 1,
          "ignored_items" => 0,
          "reviewable_items" => 1
        }
      })
    installment_group_key = Installments::Support.group_key(
      credit_card_id: credit_card.id,
      canonical_merchant_name: "MERCADO DA IMPORTACAO",
      purchase_occurred_on: Date.new(2025, 4, 26),
      amount_cents: 12_390,
      installment_total: 12
    )
    import_item = create(:import_item,
      import: import_record,
      category: category,
      installment_detected: true,
      installment_enabled: true,
      installment_group_key: installment_group_key,
      installment_number: 11,
      installment_total: 12,
      purchase_occurred_on: Date.new(2025, 4, 26),
      occurred_on: Date.new(2026, 4, 26),
      metadata: {
        "installment" => {
          "detected" => true,
          "current_number" => 11,
          "total_installments" => 12,
          "purchase_occurred_on" => "2025-04-26",
          "source_format" => "fractional_suffix"
        }
      })

    statement = described_class.new(import: import_record).call
    current_transaction = statement.transactions.find_by(import_item_id: import_item.id)
    future_transaction = user.transactions.find_by(
      installment_group_key: installment_group_key,
      installment_number: 12
    )

    expect(statement).to be_persisted
    expect(current_transaction).to be_present
    expect(current_transaction.statement).to eq(statement)
    expect(current_transaction.occurred_on).to eq(Date.new(2026, 2, 26))
    expect(current_transaction.installment_number).to eq(11)
    expect(current_transaction.purchase_occurred_on).to eq(Date.new(2025, 4, 26))
    expect(future_transaction).to be_present
    expect(future_transaction.auto_generated).to be(true)
    expect(future_transaction.statement).to be_nil
    expect(future_transaction.occurred_on).to eq(Date.new(2026, 3, 26))
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
