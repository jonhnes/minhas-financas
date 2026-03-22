require "rails_helper"

RSpec.describe RecurringRules::Materializer do
  it "creates one automatic transaction for each due rule and schedules the next run" do
    user = create(:user)
    account = create(:account, user: user)
    category = create(:category, user: user, name: "Assinaturas")
    tag = create(:tag, user: user, name: "streaming")
    rule = create(
      :recurring_rule,
      user: user,
      account: account,
      category: category,
      starts_on: Date.new(2026, 3, 22),
      next_run_on: Date.new(2026, 3, 22),
      template_payload: { "tag_ids" => [tag.id] }
    )

    created = described_class.call(Date.new(2026, 3, 22), user: user)

    expect(created.size).to eq(1)
    transaction = created.first
    expect(transaction).to have_attributes(
      auto_generated: true,
      recurring_rule_id: rule.id,
      account_id: account.id,
      category_id: category.id,
      occurred_on: Date.new(2026, 3, 22)
    )
    expect(transaction.tags.pluck(:id)).to eq([tag.id])
    expect(rule.reload.next_run_on).to eq(Date.new(2026, 4, 22))
  end
end
