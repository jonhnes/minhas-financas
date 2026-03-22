module RecurringRules
  class Materializer
    def self.call(date = Time.zone.today, user: nil)
      new(date, user: user).call
    end

    def initialize(date = Time.zone.today, user: nil)
      @date = date.to_date
      @user = user
    end

    def call
      created = []

      scope.where("next_run_on IS NULL OR next_run_on <= ?", date).find_each do |rule|
        next unless rule.due_on?(date)
        next if rule.transactions.exists?(auto_generated: true, occurred_on: date)

        transaction = create_transaction_for(rule)
        created << transaction
        rule.update!(next_run_on: RecurringRule.next_due_date_for(rule, date + 1.day))
      end

      created
    end

    private

    attr_reader :date
    attr_reader :user

    def scope
      base_scope = RecurringRule.active
      return base_scope unless user.present?

      base_scope.where(user: user)
    end

    def create_transaction_for(rule)
      transaction = rule.user.transactions.create!(
        account: rule.account,
        credit_card: rule.credit_card,
        card_holder: rule.card_holder,
        category: rule.category,
        recurring_rule: rule,
        transfer_account: transfer_account_from(rule),
        transaction_type: rule.transaction_type,
        impact_mode: rule.impact_mode,
        amount_cents: rule.amount_cents,
        occurred_on: date,
        description: rule.description,
        notes: rule.notes,
        canonical_merchant_name: rule.canonical_merchant_name,
        metadata: rule.template_payload.merge("origin" => "recurring_rule"),
        auto_generated: true
      )
      transaction.tag_ids = rule.user.tags.where(id: Array(rule.template_payload["tag_ids"])).pluck(:id)
      transaction
    end

    def transfer_account_from(rule)
      transfer_account_id = rule.template_payload["transfer_account_id"]
      return if transfer_account_id.blank?

      rule.user.accounts.find_by(id: transfer_account_id)
    end
  end
end
