module Reports
  class FilteredTransactionsQuery
    def initialize(user:, params:, scope: nil, use_month: false)
      @user = user
      @params = params
      @scope = scope || user.transactions
      @use_month = use_month
    end

    def call(exclude_third_party: false, exclude_informational: false, exclude_transfers: false)
      scoped = scope
      scoped = scoped.where(account_id: params[:account_id]) if params[:account_id].present?
      scoped = scoped.where(credit_card_id: params[:credit_card_id]) if params[:credit_card_id].present?
      scoped = scoped.where(card_holder_id: params[:card_holder_id]) if params[:card_holder_id].present?
      scoped = scoped.where(category_id: params[:category_id]) if params[:category_id].present?
      scoped = scoped.where("occurred_on >= ?", effective_occurred_from) if effective_occurred_from.present?
      scoped = scoped.where("occurred_on <= ?", effective_occurred_to) if effective_occurred_to.present?
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

    attr_reader :params, :scope, :use_month, :user

    def effective_occurred_from
      params[:occurred_from].presence || (use_month ? month_range&.begin : nil)
    end

    def effective_occurred_to
      params[:occurred_to].presence || (use_month ? month_range&.end : nil)
    end

    def month_range
      return @month_range if defined?(@month_range)
      return @month_range = nil if params[:month].blank?

      @month_range = Date.parse("#{params[:month]}-01").all_month
    end
  end
end
