class CreateImports < ActiveRecord::Migration[8.0]
  def change
    create_table :imports do |t|
      t.references :user, null: false, foreign_key: true
      t.references :credit_card, null: false, foreign_key: true
      t.references :statement, null: true, foreign_key: true
      t.string :source_kind, null: false, default: "pdf"
      t.string :provider_key, null: false
      t.string :status, null: false, default: "uploaded"
      t.jsonb :raw_payload, null: false, default: {}
      t.jsonb :parsed_payload, null: false, default: {}
      t.jsonb :error_payload, null: false, default: {}
      t.datetime :processing_started_at
      t.datetime :processing_finished_at
      t.datetime :confirmed_at

      t.timestamps
    end

    add_index :imports, [:user_id, :created_at]
    add_index :imports, [:user_id, :status]
  end
end
