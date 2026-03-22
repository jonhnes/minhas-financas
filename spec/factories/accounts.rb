FactoryBot.define do
  factory :account do
    association :user
    kind { "checking" }
    sequence(:name) { |index| "Conta #{index}" }
    institution_name { "Itaú" }
    initial_balance_cents { 250_000 }
    active { true }
    color { "#144F43" }
    icon { "bank" }
    sequence(:position) { |index| index }
  end
end
