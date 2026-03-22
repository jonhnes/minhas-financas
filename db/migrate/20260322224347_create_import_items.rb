class CreateImportItems < ActiveRecord::Migration[8.0]
  def change
    create_table :import_items do |t|
      t.references :import, null: false, foreign_key: true
      t.integer :line_index, null: false
      t.date :occurred_on, null: false
      t.string :description, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string :transaction_type, null: false, default: "expense"
      t.string :impact_mode, null: false, default: "normal"
      t.references :category, null: true, foreign_key: true
      t.references :card_holder, null: true, foreign_key: true
      t.string :canonical_merchant_name
      t.string :raw_holder_name
      t.string :status, null: false, default: "pending_review"
      t.boolean :ignored, null: false, default: false
      t.jsonb :metadata, null: false, default: {}
      t.bigint :linked_transaction_id

      t.timestamps
    end

    add_foreign_key :import_items, :transactions, column: :linked_transaction_id
    add_index :import_items, :linked_transaction_id
    add_index :import_items, [:import_id, :line_index], unique: true
    add_index :import_items, [:import_id, :status]
  end
end
