class CreateCategorySuggestionRules < ActiveRecord::Migration[8.0]
  def change
    create_table :category_suggestion_rules do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: true, foreign_key: { on_delete: :nullify }
      t.string :match_type, null: false
      t.string :pattern, null: false
      t.string :normalized_pattern, null: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :category_suggestion_rules, [:user_id, :active, :position], name: "index_category_suggestion_rules_on_user_active_position"
    add_index :category_suggestion_rules, [:user_id, :normalized_pattern], name: "index_category_suggestion_rules_on_user_normalized_pattern"
  end
end
