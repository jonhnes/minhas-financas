module Api
  module V1
    module ResourceLookup
      extend ActiveSupport::Concern

      private

      def lookup_account(id)
        return if id.blank?

        current_user.accounts.find(id)
      end

      def lookup_credit_card(id)
        return if id.blank?

        current_user.credit_cards.find(id)
      end

      def lookup_card_holder(id)
        return if id.blank?

        CardHolder.joins(:credit_card).where(credit_cards: { user_id: current_user.id }).find(id)
      end

      def lookup_category(id)
        return if id.blank?

        policy_scope(Category).find(id)
      end

      def lookup_budget_category(id)
        return if id.blank?

        policy_scope(Category).root_only.find(id)
      end

      def lookup_subcategory(id)
        return if id.blank?

        policy_scope(Category).where.not(parent_id: nil).find(id)
      end

      def lookup_tag_ids(ids)
        return [] if ids.blank?

        current_user.tags.where(id: ids).pluck(:id)
      end

      def lookup_statement(id)
        return if id.blank?

        Statement.joins(:credit_card).where(credit_cards: { user_id: current_user.id }).find(id)
      end
    end
  end
end
