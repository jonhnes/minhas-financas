module Reports
  class BudgetStatusQuery
    def initialize(user:, params:)
      @user = user
      @params = params
    end

    def call
      range = current_period
      budgets.map do |budget|
        spent_cents = scoped_expenses
          .where(occurred_on: range, category_id: budget.subcategory_id || budget.category_id)
          .sum(:amount_cents)

        {
          budget: budget,
          spent_cents: spent_cents,
          ratio: budget.amount_cents.zero? ? 0 : (spent_cents.to_f / budget.amount_cents),
          period: range.to_s
        }
      end
    end

    private

    attr_reader :params, :user

    def budgets
      @budgets ||= user.budgets.active.includes(:category, :subcategory)
    end

    def scoped_expenses
      @scoped_expenses ||= user.transactions.where(transaction_type: "expense", impact_mode: "normal")
    end

    def current_period
      return Date.parse("#{params[:month]}-01").all_month if params[:month].present?

      Time.zone.today.all_month
    end
  end
end
