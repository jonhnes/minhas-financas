module Api
  module V1
    module Serializers
      module_function

      def user(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          timezone: user.timezone,
          locale: user.locale,
          onboarding_completed_at: user.onboarding_completed_at,
          onboarding_completed: user.onboarding_completed?
        }
      end

      def account(account)
        {
          id: account.id,
          kind: account.kind,
          name: account.name,
          institution_name: account.institution_name,
          initial_balance_cents: account.initial_balance_cents,
          current_balance_cents: account.current_balance,
          active: account.active,
          color: account.color,
          icon: account.icon,
          position: account.position
        }
      end

      def credit_card(card)
        {
          id: card.id,
          payment_account_id: card.payment_account_id,
          name: card.name,
          brand: card.brand,
          credit_limit_cents: card.credit_limit_cents,
          closing_day: card.closing_day,
          due_day: card.due_day,
          active: card.active,
          color: card.color,
          cycle_total_cents: card.cycle_total
        }
      end

      def card_holder(holder)
        {
          id: holder.id,
          credit_card_id: holder.credit_card_id,
          name: holder.name,
          holder_type: holder.holder_type,
          active: holder.active,
          position: holder.position
        }
      end

      def category(category)
        {
          id: category.id,
          user_id: category.user_id,
          parent_id: category.parent_id,
          name: category.name,
          color: category.color,
          icon: category.icon,
          position: category.position,
          system: category.system,
          active: category.active
        }
      end

      def tag(tag)
        {
          id: tag.id,
          name: tag.name,
          color: tag.color
        }
      end

      def transaction(transaction)
        {
          id: transaction.id,
          account_id: transaction.account_id,
          credit_card_id: transaction.credit_card_id,
          card_holder_id: transaction.card_holder_id,
          category_id: transaction.category_id,
          recurring_rule_id: transaction.recurring_rule_id,
          transfer_account_id: transaction.transfer_account_id,
          transaction_type: transaction.transaction_type,
          impact_mode: transaction.impact_mode,
          amount_cents: transaction.amount_cents,
          occurred_on: transaction.occurred_on,
          description: transaction.description,
          notes: transaction.notes,
          canonical_merchant_name: transaction.canonical_merchant_name,
          metadata: transaction.metadata,
          auto_generated: transaction.auto_generated,
          account_name: transaction.account&.name,
          credit_card_name: transaction.credit_card&.name,
          card_holder_name: transaction.card_holder&.name,
          category_name: transaction.category&.name,
          transfer_account_name: transaction.transfer_account&.name,
          tags: transaction.tags.map { |tag_record| Api::V1::Serializers.tag(tag_record) }
        }
      end

      def budget(budget, spent_cents: nil)
        {
          id: budget.id,
          category_id: budget.category_id,
          subcategory_id: budget.subcategory_id,
          amount_cents: budget.amount_cents,
          period_type: budget.period_type,
          active: budget.active,
          spent_cents: spent_cents,
          category_name: budget.category.name,
          subcategory_name: budget.subcategory&.name
        }.compact
      end

      def recurring_rule(rule)
        {
          id: rule.id,
          account_id: rule.account_id,
          credit_card_id: rule.credit_card_id,
          card_holder_id: rule.card_holder_id,
          category_id: rule.category_id,
          frequency: rule.frequency,
          starts_on: rule.starts_on,
          ends_on: rule.ends_on,
          active: rule.active,
          transaction_type: rule.transaction_type,
          impact_mode: rule.impact_mode,
          amount_cents: rule.amount_cents,
          description: rule.description,
          notes: rule.notes,
          canonical_merchant_name: rule.canonical_merchant_name,
          template_payload: rule.template_payload,
          next_run_on: rule.next_run_on,
          category_name: rule.category&.name,
          card_holder_name: rule.card_holder&.name
        }
      end
    end
  end
end
