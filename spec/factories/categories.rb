FactoryBot.define do
  factory :category do
    association :user
    sequence(:name) { |index| "Categoria #{index}" }
    color { "#144F43" }
    icon { "tag" }
    sequence(:position) { |index| index }
    system { false }
    active { true }
    parent { nil }

    trait :system_default do
      user { nil }
      system { true }
    end
  end
end
