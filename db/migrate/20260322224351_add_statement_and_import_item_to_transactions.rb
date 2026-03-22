class AddStatementAndImportItemToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_reference :transactions, :statement, null: true, foreign_key: true
    add_column :transactions, :import_item_id, :bigint
    add_foreign_key :transactions, :import_items, column: :import_item_id
    add_index :transactions, :import_item_id, unique: true
  end
end
