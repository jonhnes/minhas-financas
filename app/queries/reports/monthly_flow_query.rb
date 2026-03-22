module Reports
  class MonthlyFlowQuery
    def initialize(user:, params:)
      @user = user
      @params = params
    end

    def call
      range = months_range
      grouped = Hash.new { |hash, key| hash[key] = { month: key.to_s, income_cents: 0, expense_cents: 0 } }

      filtered_transactions.call(exclude_third_party: !include_third_party?, exclude_informational: true, exclude_transfers: true)
        .where(occurred_on: range)
        .find_each do |transaction|
          month = transaction.occurred_on.beginning_of_month
          bucket = grouped[month]
          if transaction.income?
            bucket[:income_cents] += transaction.amount_cents
          elsif transaction.expense?
            bucket[:expense_cents] += transaction.amount_cents
          end
        end

      range.step(range.end, 1.month).map do |month|
        grouped[month.beginning_of_month]
      end
    end

    private

    attr_reader :params, :user

    def filtered_transactions
      @filtered_transactions ||= Reports::FilteredTransactionsQuery.new(user: user, params: params)
    end

    def months_range
      end_month = params[:month].present? ? Date.parse("#{params[:month]}-01").end_of_month : Time.zone.today.end_of_month
      start_month = (end_month - 5.months).beginning_of_month
      start_month..end_month
    end

    def include_third_party?
      ActiveModel::Type::Boolean.new.cast(params[:include_third_party])
    end
  end
end
