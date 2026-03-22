FactoryBot.define do
  factory :tag do
    association :user
    sequence(:name) { |index| "Tag #{index}" }
    color { "#D98D30" }
  end
end
