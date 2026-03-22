class CreateStatements < ActiveRecord::Migration[8.0]
  def change
    create_table :statements do |t|
      t.references :credit_card, null: false, foreign_key: true
      t.date :period_start, null: false
      t.date :period_end, null: false
      t.date :due_date, null: false
      t.integer :total_amount_cents, null: false, default: 0
      t.string :status, null: false, default: "open"
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :statements, [:credit_card_id, :period_start, :period_end], unique: true, name: "index_statements_on_card_and_period"
  end
end
