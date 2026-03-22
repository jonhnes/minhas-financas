FactoryBot.define do
  factory :transaction do
    association :user
    account { association :account, user: user }
    credit_card { nil }
    card_holder { nil }
    category { association :category, user: user }
    recurring_rule { nil }
    transfer_account { nil }
    transaction_type { "expense" }
    impact_mode { "normal" }
    amount_cents { 5_000 }
    occurred_on { Date.new(2026, 3, 22) }
    sequence(:description) { |index| "Compra #{index}" }
    notes { nil }
    canonical_merchant_name { "Merchant" }
    metadata { {} }
    auto_generated { false }

    trait :income do
      transaction_type { "income" }
      description { "Salário" }
      amount_cents { 500_000 }
    end

    trait :third_party do
      impact_mode { "third_party" }
    end

    trait :off_budget do
      impact_mode { "off_budget" }
    end

    trait :transfer do
      transaction_type { "transfer" }
      association :transfer_account, factory: :account
      category { nil }
    end

    trait :credit_card_purchase do
      account { nil }
      association :credit_card
    end
  end
end
