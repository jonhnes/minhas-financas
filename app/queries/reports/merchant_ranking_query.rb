module Reports
  class MerchantRankingQuery
    def initialize(user:, params:)
      @user = user
      @params = params
    end

    def call
      filtered_transactions.call(exclude_third_party: !include_third_party?, exclude_informational: true, exclude_transfers: true)
        .where(transaction_type: "expense")
        .group_by { |transaction| transaction.canonical_merchant_name.presence || transaction.description }
        .map do |merchant_name, transactions|
          {
            merchant_name: merchant_name,
            amount_cents: transactions.sum(&:amount_cents),
            transactions_count: transactions.length
          }
        end
        .sort_by { |entry| [-entry[:amount_cents], -entry[:transactions_count]] }
        .first(10)
    end

    private

    attr_reader :params, :user

    def filtered_transactions
      @filtered_transactions ||= Reports::FilteredTransactionsQuery.new(user: user, params: params)
    end

    def include_third_party?
      ActiveModel::Type::Boolean.new.cast(params[:include_third_party])
    end
  end
end
