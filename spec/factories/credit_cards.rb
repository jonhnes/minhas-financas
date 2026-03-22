FactoryBot.define do
  factory :credit_card do
    association :user
    association :payment_account, factory: :account
    sequence(:name) { |index| "Cartão #{index}" }
    brand { "Visa" }
    credit_limit_cents { 500_000 }
    closing_day { 5 }
    due_day { 12 }
    active { true }
    color { "#1F5564" }
  end
end
