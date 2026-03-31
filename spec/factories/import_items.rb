FactoryBot.define do
  factory :import_item do
    association :import
    line_index { 1 }
    occurred_on { Date.new(2026, 2, 10) }
    description { "Mercado da importação" }
    amount_cents { 12_390 }
    transaction_type { "expense" }
    impact_mode { "normal" }
    category { association :category, user: import.user }
    card_holder { nil }
    canonical_merchant_name { "MERCADO DA IMPORTACAO" }
    raw_holder_name { nil }
    status { "pending_review" }
    ignored { false }
    metadata { {} }
    linked_transaction_id { nil }
    installment_detected { false }
    installment_enabled { false }
    installment_group_key { nil }
    installment_number { nil }
    installment_total { nil }
    purchase_occurred_on { nil }
  end
end
