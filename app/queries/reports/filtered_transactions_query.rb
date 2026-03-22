module Reports
  class FilteredTransactionsQuery
    def initialize(user:, params:, scope: nil)
      @user = user
      @params = params
      @scope = scope || user.transactions
    end

    def call(exclude_third_party: false, exclude_informational: false, exclude_transfers: false)
      scoped = scope
      scoped = scoped.where(account_id: params[:account_id]) if params[:account_id].present?
      scoped = scoped.where(credit_card_id: params[:credit_card_id]) if params[:credit_card_id].present?
      scoped = scoped.where(card_holder_id: params[:card_holder_id]) if params[:card_holder_id].present?
      scoped = scoped.where(category_id: params[:category_id]) if params[:category_id].present?
      scoped = scoped.where("occurred_on >= ?", params[:occurred_from]) if params[:occurred_from].present?
      scoped = scoped.where("occurred_on <= ?", params[:occurred_to]) if params[:occurred_to].present?
      scoped = scoped.joins(:transaction_tags).where(transaction_tags: { tag_id: params[:tag_id] }) if params[:tag_id].present?

      if params[:query].present?
        query = "%#{params[:query].strip}%"
        scoped = scoped.where("description ILIKE :query OR canonical_merchant_name ILIKE :query", query: query)
      end

      scoped = scoped.where.not(impact_mode: "third_party") if exclude_third_party
      scoped = scoped.where.not(impact_mode: "informational") if exclude_informational
      scoped = scoped.where.not(transaction_type: "transfer") if exclude_transfers
      scoped
    end

    private

    attr_reader :params, :scope, :user
  end
end
