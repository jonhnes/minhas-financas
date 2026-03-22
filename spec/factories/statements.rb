FactoryBot.define do
  factory :statement do
    association :credit_card
    period_start { Date.new(2026, 2, 3) }
    period_end { Date.new(2026, 3, 2) }
    due_date { Date.new(2026, 3, 15) }
    total_amount_cents { 130_000 }
    status { "open" }
    metadata { {} }
  end
end
