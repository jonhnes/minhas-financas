# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_05_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.string "institution_name"
    t.integer "initial_balance_cents", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.string "color", default: "#144F43", null: false
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "active"], name: "index_accounts_on_user_id_and_active"
    t.index ["user_id", "name"], name: "index_accounts_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "budgets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.bigint "subcategory_id"
    t.integer "amount_cents", default: 0, null: false
    t.string "period_type", default: "monthly", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_budgets_on_category_id"
    t.index ["subcategory_id"], name: "index_budgets_on_subcategory_id"
    t.index ["user_id", "category_id", "subcategory_id", "period_type"], name: "index_budgets_on_scope_and_period", unique: true
    t.index ["user_id"], name: "index_budgets_on_user_id"
  end

  create_table "card_holders", force: :cascade do |t|
    t.bigint "credit_card_id", null: false
    t.string "name", null: false
    t.string "holder_type", default: "owner", null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_card_id", "name"], name: "index_card_holders_on_credit_card_id_and_name", unique: true
    t.index ["credit_card_id"], name: "index_card_holders_on_credit_card_id"
  end

  create_table "categories", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "parent_id"
    t.string "name", null: false
    t.string "color", default: "#144F43", null: false
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.boolean "system", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
    t.index ["system"], name: "index_categories_on_system"
    t.index ["user_id", "parent_id", "name"], name: "index_categories_on_user_id_and_parent_id_and_name", unique: true
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "category_suggestion_rules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id"
    t.string "match_type", null: false
    t.string "pattern", null: false
    t.string "normalized_pattern", null: false
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_category_suggestion_rules_on_category_id"
    t.index ["user_id", "active", "position"], name: "index_category_suggestion_rules_on_user_active_position"
    t.index ["user_id", "normalized_pattern"], name: "index_category_suggestion_rules_on_user_normalized_pattern"
    t.index ["user_id"], name: "index_category_suggestion_rules_on_user_id"
  end

  create_table "credit_cards", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "payment_account_id"
    t.string "name", null: false
    t.string "brand"
    t.integer "credit_limit_cents", default: 0, null: false
    t.integer "closing_day", null: false
    t.integer "due_day", null: false
    t.boolean "active", default: true, null: false
    t.string "color", default: "#1F5564", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_account_id"], name: "index_credit_cards_on_payment_account_id"
    t.index ["user_id", "active"], name: "index_credit_cards_on_user_id_and_active"
    t.index ["user_id", "name"], name: "index_credit_cards_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_credit_cards_on_user_id"
  end

  create_table "import_items", force: :cascade do |t|
    t.bigint "import_id", null: false
    t.integer "line_index", null: false
    t.date "occurred_on", null: false
    t.string "description", null: false
    t.integer "amount_cents", default: 0, null: false
    t.string "transaction_type", default: "expense", null: false
    t.string "impact_mode", default: "normal", null: false
    t.bigint "category_id"
    t.bigint "card_holder_id"
    t.string "canonical_merchant_name"
    t.string "raw_holder_name"
    t.string "status", default: "pending_review", null: false
    t.boolean "ignored", default: false, null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "linked_transaction_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "installment_detected", default: false, null: false
    t.boolean "installment_enabled", default: false, null: false
    t.string "installment_group_key"
    t.integer "installment_number"
    t.integer "installment_total"
    t.date "purchase_occurred_on"
    t.index ["card_holder_id"], name: "index_import_items_on_card_holder_id"
    t.index ["category_id"], name: "index_import_items_on_category_id"
    t.index ["import_id", "line_index"], name: "index_import_items_on_import_id_and_line_index", unique: true
    t.index ["import_id", "status"], name: "index_import_items_on_import_id_and_status"
    t.index ["import_id"], name: "index_import_items_on_import_id"
    t.index ["linked_transaction_id"], name: "index_import_items_on_linked_transaction_id"
  end

  create_table "imports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "credit_card_id", null: false
    t.bigint "statement_id"
    t.string "source_kind", default: "pdf", null: false
    t.string "provider_key", null: false
    t.string "status", default: "uploaded", null: false
    t.jsonb "raw_payload", default: {}, null: false
    t.jsonb "parsed_payload", default: {}, null: false
    t.jsonb "error_payload", default: {}, null: false
    t.datetime "processing_started_at"
    t.datetime "processing_finished_at"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_card_id"], name: "index_imports_on_credit_card_id"
    t.index ["statement_id"], name: "index_imports_on_statement_id"
    t.index ["user_id", "created_at"], name: "index_imports_on_user_id_and_created_at"
    t.index ["user_id", "status"], name: "index_imports_on_user_id_and_status"
    t.index ["user_id"], name: "index_imports_on_user_id"
  end

  create_table "mobile_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "access_token_digest", null: false
    t.string "refresh_token_digest", null: false
    t.string "platform"
    t.string "device_label"
    t.datetime "expires_at", null: false
    t.datetime "refresh_expires_at", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_token_digest"], name: "index_mobile_sessions_on_access_token_digest", unique: true
    t.index ["refresh_expires_at"], name: "index_mobile_sessions_on_refresh_expires_at"
    t.index ["refresh_token_digest"], name: "index_mobile_sessions_on_refresh_token_digest", unique: true
    t.index ["user_id", "revoked_at"], name: "index_mobile_sessions_on_user_id_and_revoked_at"
    t.index ["user_id"], name: "index_mobile_sessions_on_user_id"
  end

  create_table "recurring_rules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "account_id"
    t.bigint "credit_card_id"
    t.bigint "card_holder_id"
    t.bigint "category_id"
    t.string "frequency", null: false
    t.date "starts_on", null: false
    t.date "ends_on"
    t.boolean "active", default: true, null: false
    t.string "transaction_type", default: "expense", null: false
    t.string "impact_mode", default: "normal", null: false
    t.integer "amount_cents", default: 0, null: false
    t.string "description", null: false
    t.text "notes"
    t.string "canonical_merchant_name"
    t.jsonb "template_payload", default: {}, null: false
    t.date "next_run_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_recurring_rules_on_account_id"
    t.index ["card_holder_id"], name: "index_recurring_rules_on_card_holder_id"
    t.index ["category_id"], name: "index_recurring_rules_on_category_id"
    t.index ["credit_card_id"], name: "index_recurring_rules_on_credit_card_id"
    t.index ["user_id", "active", "next_run_on"], name: "index_recurring_rules_on_user_id_and_active_and_next_run_on"
    t.index ["user_id"], name: "index_recurring_rules_on_user_id"
  end

  create_table "statements", force: :cascade do |t|
    t.bigint "credit_card_id", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.date "due_date", null: false
    t.integer "total_amount_cents", default: 0, null: false
    t.string "status", default: "open", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_card_id", "period_start", "period_end"], name: "index_statements_on_card_and_period", unique: true
    t.index ["credit_card_id"], name: "index_statements_on_credit_card_id"
  end

  create_table "tags", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "color", default: "#D98D30", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "transaction_tags", force: :cascade do |t|
    t.bigint "transaction_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_transaction_tags_on_tag_id"
    t.index ["transaction_id", "tag_id"], name: "index_transaction_tags_on_transaction_id_and_tag_id", unique: true
    t.index ["transaction_id"], name: "index_transaction_tags_on_transaction_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "account_id"
    t.bigint "credit_card_id"
    t.bigint "card_holder_id"
    t.bigint "category_id"
    t.bigint "recurring_rule_id"
    t.bigint "transfer_account_id"
    t.string "transaction_type", null: false
    t.string "impact_mode", default: "normal", null: false
    t.integer "amount_cents", default: 0, null: false
    t.date "occurred_on", null: false
    t.string "description", null: false
    t.text "notes"
    t.string "canonical_merchant_name"
    t.jsonb "metadata", default: {}, null: false
    t.boolean "auto_generated", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "statement_id"
    t.bigint "import_item_id"
    t.string "installment_group_key"
    t.integer "installment_number"
    t.integer "installment_total"
    t.date "purchase_occurred_on"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["card_holder_id"], name: "index_transactions_on_card_holder_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["credit_card_id", "occurred_on"], name: "index_transactions_on_credit_card_id_and_occurred_on"
    t.index ["credit_card_id"], name: "index_transactions_on_credit_card_id"
    t.index ["import_item_id"], name: "index_transactions_on_import_item_id", unique: true
    t.index ["metadata"], name: "index_transactions_on_metadata", using: :gin
    t.index ["recurring_rule_id"], name: "index_transactions_on_recurring_rule_id"
    t.index ["statement_id"], name: "index_transactions_on_statement_id"
    t.index ["transfer_account_id"], name: "index_transactions_on_transfer_account_id"
    t.index ["user_id", "impact_mode"], name: "index_transactions_on_user_id_and_impact_mode"
    t.index ["user_id", "installment_group_key", "installment_number"], name: "index_transactions_on_user_and_installment_group", unique: true, where: "(installment_group_key IS NOT NULL)"
    t.index ["user_id", "occurred_on"], name: "index_transactions_on_user_id_and_occurred_on"
    t.index ["user_id", "transaction_type"], name: "index_transactions_on_user_id_and_transaction_type"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name", null: false
    t.string "timezone", default: "America/Sao_Paulo", null: false
    t.string "locale", default: "pt-BR", null: false
    t.datetime "onboarding_completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "ui_preferences", default: {}, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "budgets", "categories"
  add_foreign_key "budgets", "categories", column: "subcategory_id"
  add_foreign_key "budgets", "users"
  add_foreign_key "card_holders", "credit_cards"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "categories", "users"
  add_foreign_key "category_suggestion_rules", "categories", on_delete: :nullify
  add_foreign_key "category_suggestion_rules", "users"
  add_foreign_key "credit_cards", "accounts", column: "payment_account_id"
  add_foreign_key "credit_cards", "users"
  add_foreign_key "import_items", "card_holders"
  add_foreign_key "import_items", "categories"
  add_foreign_key "import_items", "imports"
  add_foreign_key "import_items", "transactions", column: "linked_transaction_id"
  add_foreign_key "imports", "credit_cards"
  add_foreign_key "imports", "statements"
  add_foreign_key "imports", "users"
  add_foreign_key "mobile_sessions", "users"
  add_foreign_key "recurring_rules", "accounts"
  add_foreign_key "recurring_rules", "card_holders"
  add_foreign_key "recurring_rules", "categories"
  add_foreign_key "recurring_rules", "credit_cards"
  add_foreign_key "recurring_rules", "users"
  add_foreign_key "statements", "credit_cards"
  add_foreign_key "tags", "users"
  add_foreign_key "transaction_tags", "tags"
  add_foreign_key "transaction_tags", "transactions"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "accounts", column: "transfer_account_id"
  add_foreign_key "transactions", "card_holders"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "credit_cards"
  add_foreign_key "transactions", "import_items"
  add_foreign_key "transactions", "recurring_rules"
  add_foreign_key "transactions", "statements"
  add_foreign_key "transactions", "users"
end
