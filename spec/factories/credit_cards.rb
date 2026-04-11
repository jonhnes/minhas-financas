FactoryBot.define do
  factory :credit_card do
    association :user
    payment_account { association :account, user: user }
    sequence(:name) { |index| "Cartão #{index}" }
    brand { "Visa" }
    last_four_digits { nil }
    credit_limit_cents { 500_000 }
    closing_day { 5 }
    due_day { 12 }
    active { true }
    color { "#1F5564" }
  end
end
