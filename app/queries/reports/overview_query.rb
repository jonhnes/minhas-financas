module Reports
  class OverviewQuery
    def initialize(user:, params:)
      @user = user
      @params = params
    end

    def call
      range = current_period
      scoped = filtered_transactions.call(exclude_third_party: !include_third_party?, exclude_informational: true)

      {
        period: range.to_s,
        consolidated_balance_cents: consolidated_balance_cents(scoped, range),
        monthly_income_cents: scoped.where(transaction_type: "income", occurred_on: range).sum(:amount_cents),
        monthly_expense_cents: scoped.where(transaction_type: "expense", occurred_on: range).sum(:amount_cents),
        open_card_cycle_cents: user.credit_cards.active.sum { |card| card.cycle_total(range.end, include_third_party: include_third_party?) },
        budgets_over_limit_count: budget_snapshot.count { |entry| entry[:ratio] > 1.0 },
        critical_budgets: budget_snapshot.select { |entry| entry[:ratio] >= 0.8 }.first(3).map do |entry|
          Api::V1::Serializers.budget(entry[:budget], spent_cents: entry[:spent_cents]).merge(ratio: entry[:ratio])
        end
      }
    end

    private

    attr_reader :params, :user

    def filtered_transactions
      @filtered_transactions ||= Reports::FilteredTransactionsQuery.new(user: user, params: params)
    end

    def budget_snapshot
      @budget_snapshot ||= Reports::BudgetStatusQuery.new(user: user, params: params).call
    end

    def current_period
      return Date.parse("#{params[:month]}-01").all_month if params[:month].present?

      Time.zone.today.all_month
    end

    def include_third_party?
      ActiveModel::Type::Boolean.new.cast(params[:include_third_party])
    end

    def consolidated_balance_cents(scope, range)
      initial_balance_cents = user.accounts.sum(:initial_balance_cents)
      posted_delta_cents = scope
        .where("occurred_on <= ?", range.end)
        .includes(:account, :transfer_account)
        .sum { |transaction| transaction.account_delta_cents + transaction.transfer_delta_cents }

      initial_balance_cents + posted_delta_cents
    end
  end
end
