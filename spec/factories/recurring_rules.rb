FactoryBot.define do
  factory :recurring_rule do
    association :user
    association :account
    credit_card { nil }
    card_holder { nil }
    association :category
    frequency { "monthly" }
    starts_on { Date.new(2026, 3, 5) }
    ends_on { nil }
    active { true }
    transaction_type { "expense" }
    impact_mode { "normal" }
    amount_cents { 14_900 }
    description { "Netflix" }
    notes { nil }
    canonical_merchant_name { "Netflix" }
    template_payload { {} }
    next_run_on { starts_on }
  end
end
