class AddInstallmentFieldsToImportItemsAndTransactions < ActiveRecord::Migration[8.0]
  def change
    change_table :import_items, bulk: true do |t|
      t.boolean :installment_detected, null: false, default: false
      t.boolean :installment_enabled, null: false, default: false
      t.string :installment_group_key
      t.integer :installment_number
      t.integer :installment_total
      t.date :purchase_occurred_on
    end

    change_table :transactions, bulk: true do |t|
      t.string :installment_group_key
      t.integer :installment_number
      t.integer :installment_total
      t.date :purchase_occurred_on
    end

    add_index :transactions,
      %i[user_id installment_group_key installment_number],
      unique: true,
      where: "installment_group_key IS NOT NULL",
      name: "index_transactions_on_user_and_installment_group"
  end
end
