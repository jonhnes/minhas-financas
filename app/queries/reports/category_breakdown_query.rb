module Reports
  class CategoryBreakdownQuery
    def initialize(user:, params:)
      @user = user
      @params = params
    end

    def call
      filtered_transactions.call(exclude_third_party: !include_third_party?, exclude_informational: true, exclude_transfers: true)
        .where(transaction_type: "expense")
        .group_by { |transaction| transaction.category&.name || "Sem categoria" }
        .map do |name, transactions|
          {
            category_name: name,
            amount_cents: transactions.sum(&:amount_cents),
            transactions_count: transactions.length
          }
        end
        .sort_by { |entry| -entry[:amount_cents] }
    end

    private

    attr_reader :params, :user

    def filtered_transactions
      @filtered_transactions ||= Reports::FilteredTransactionsQuery.new(
        user: user,
        params: params,
        scope: user.transactions.includes(:category)
      )
    end

    def include_third_party?
      ActiveModel::Type::Boolean.new.cast(params[:include_third_party])
    end
  end
end
