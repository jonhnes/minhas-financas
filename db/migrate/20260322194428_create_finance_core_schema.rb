class CreateFinanceCoreSchema < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :name, null: false
      t.string :institution_name
      t.integer :initial_balance_cents, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.string :color, null: false, default: "#144F43"
      t.string :icon
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :accounts, [:user_id, :name], unique: true
    add_index :accounts, [:user_id, :active]

    create_table :credit_cards do |t|
      t.references :user, null: false, foreign_key: true
      t.references :payment_account, foreign_key: { to_table: :accounts }
      t.string :name, null: false
      t.string :brand
      t.integer :credit_limit_cents, null: false, default: 0
      t.integer :closing_day, null: false
      t.integer :due_day, null: false
      t.boolean :active, null: false, default: true
      t.string :color, null: false, default: "#1F5564"

      t.timestamps
    end

    add_index :credit_cards, [:user_id, :name], unique: true
    add_index :credit_cards, [:user_id, :active]

    create_table :card_holders do |t|
      t.references :credit_card, null: false, foreign_key: true
      t.string :name, null: false
      t.string :holder_type, null: false, default: "owner"
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :card_holders, [:credit_card_id, :name], unique: true

    create_table :categories do |t|
      t.references :user, foreign_key: true
      t.references :parent, foreign_key: { to_table: :categories }
      t.string :name, null: false
      t.string :color, null: false, default: "#144F43"
      t.string :icon
      t.integer :position, null: false, default: 0
      t.boolean :system, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :categories, [:user_id, :parent_id, :name], unique: true
    add_index :categories, :system

    create_table :tags do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color, null: false, default: "#D98D30"

      t.timestamps
    end

    add_index :tags, [:user_id, :name], unique: true

    create_table :recurring_rules do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, foreign_key: true
      t.references :credit_card, foreign_key: true
      t.references :card_holder, foreign_key: true
      t.references :category, foreign_key: true
      t.string :frequency, null: false
      t.date :starts_on, null: false
      t.date :ends_on
      t.boolean :active, null: false, default: true
      t.string :transaction_type, null: false, default: "expense"
      t.string :impact_mode, null: false, default: "normal"
      t.integer :amount_cents, null: false, default: 0
      t.string :description, null: false
      t.text :notes
      t.string :canonical_merchant_name
      t.jsonb :template_payload, null: false, default: {}
      t.date :next_run_on

      t.timestamps
    end

    add_index :recurring_rules, [:user_id, :active, :next_run_on]

    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, foreign_key: true
      t.references :credit_card, foreign_key: true
      t.references :card_holder, foreign_key: true
      t.references :category, foreign_key: true
      t.references :recurring_rule, foreign_key: true
      t.references :transfer_account, foreign_key: { to_table: :accounts }
      t.string :transaction_type, null: false
      t.string :impact_mode, null: false, default: "normal"
      t.integer :amount_cents, null: false, default: 0
      t.date :occurred_on, null: false
      t.string :description, null: false
      t.text :notes
      t.string :canonical_merchant_name
      t.jsonb :metadata, null: false, default: {}
      t.boolean :auto_generated, null: false, default: false

      t.timestamps
    end

    add_index :transactions, [:user_id, :occurred_on]
    add_index :transactions, [:user_id, :impact_mode]
    add_index :transactions, [:user_id, :transaction_type]
    add_index :transactions, [:credit_card_id, :occurred_on]
    add_index :transactions, :metadata, using: :gin

    create_table :transaction_tags do |t|
      t.references :transaction, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :transaction_tags, [:transaction_id, :tag_id], unique: true

    create_table :budgets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.references :subcategory, foreign_key: { to_table: :categories }
      t.integer :amount_cents, null: false, default: 0
      t.string :period_type, null: false, default: "monthly"
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :budgets, [:user_id, :category_id, :subcategory_id, :period_type],
      unique: true,
      name: "index_budgets_on_scope_and_period"
  end
end
