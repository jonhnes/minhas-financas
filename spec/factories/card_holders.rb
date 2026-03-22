FactoryBot.define do
  factory :card_holder do
    association :credit_card
    sequence(:name) { |index| "Portador #{index}" }
    holder_type { "additional" }
    active { true }
    sequence(:position) { |index| index }
  end
end
