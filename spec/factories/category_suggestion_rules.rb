FactoryBot.define do
  factory :category_suggestion_rule do
    association :user
    category { association :category, user: user }
    match_type { "contains" }
    sequence(:pattern) { |index| "Mercado #{index}" }
    active { true }
    sequence(:position) { |index| index }
  end
end
