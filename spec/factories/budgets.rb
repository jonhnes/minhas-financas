FactoryBot.define do
  factory :budget do
    association :user
    association :category
    amount_cents { 150_000 }
    period_type { "monthly" }
    active { true }
    subcategory { nil }
  end
end
