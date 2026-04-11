module Api
  module V1
    module Serializers
      module_function

      def installment_payload(record, include_flags: false)
        return nil if record.installment_group_key.blank? || record.installment_number.blank? || record.installment_total.blank? || record.purchase_occurred_on.blank?

        payload = {
          group_key: record.installment_group_key,
          current_number: record.installment_number,
          total_installments: record.installment_total,
          purchase_occurred_on: record.purchase_occurred_on
        }

        if include_flags
          payload[:detected] = record.installment_detected
          payload[:enabled] = record.installment_enabled
        end

        payload
      end

      def user(user)
        {
          id: user.id,
          name: user.name,
          email: user.email,
          timezone: user.timezone,
          locale: user.locale,
          ui_preferences: user.ui_preferences || {},
          onboarding_completed_at: user.onboarding_completed_at,
          onboarding_completed: user.onboarding_completed?
        }
      end

      def user_onboarding(user)
        {
          has_account: user.accounts.exists?,
          has_credit_card: user.credit_cards.exists?,
          completed: user.onboarding_completed?
        }
      end

      def user_with_onboarding(user)
        user(user).merge(onboarding: user_onboarding(user))
      end

      def mobile_auth_session(session, access_token:, refresh_token:)
        {
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: session.expires_at,
          user: user_with_onboarding(session.user)
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
          last_four_digits: card.last_four_digits,
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

      def category_suggestion_rule(rule)
        {
          id: rule.id,
          user_id: rule.user_id,
          category_id: rule.category_id,
          category_name: rule.category&.name,
          match_type: rule.match_type,
          pattern: rule.pattern,
          normalized_pattern: rule.normalized_pattern,
          active: rule.active,
          position: rule.position
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
          statement_id: transaction.statement_id,
          import_item_id: transaction.import_item_id,
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
          installment: installment_payload(transaction),
          account_name: transaction.account&.name,
          credit_card_name: transaction.credit_card&.name,
          card_holder_name: transaction.card_holder&.name,
          category_name: transaction.category&.name,
          statement_due_date: transaction.statement&.due_date,
          transfer_account_name: transaction.transfer_account&.name,
          tags: transaction.tags.map { |tag_record| Api::V1::Serializers.tag(tag_record) }
        }
      end

      def statement(statement)
        {
          id: statement.id,
          credit_card_id: statement.credit_card_id,
          credit_card_name: statement.credit_card.name,
          period_start: statement.period_start,
          period_end: statement.period_end,
          due_date: statement.due_date,
          total_amount_cents: statement.total_amount_cents,
          status: statement.status,
          metadata: statement.metadata,
          transactions_count: statement.transactions.size
        }
      end

      def import_item(import_item)
        {
          id: import_item.id,
          import_id: import_item.import_id,
          linked_transaction_id: import_item.linked_transaction_id,
          line_index: import_item.line_index,
          occurred_on: import_item.occurred_on,
          description: import_item.description,
          amount_cents: import_item.amount_cents,
          transaction_type: import_item.transaction_type,
          impact_mode: import_item.impact_mode,
          category_id: import_item.category_id,
          category_name: import_item.category&.name,
          card_holder_id: import_item.card_holder_id,
          card_holder_name: import_item.card_holder&.name,
          canonical_merchant_name: import_item.canonical_merchant_name,
          raw_holder_name: import_item.raw_holder_name,
          status: import_item.status,
          ignored: import_item.ignored,
          metadata: import_item.metadata,
          installment: installment_payload(import_item, include_flags: true)
        }
      end

      def import(import_record, include_items: false)
        items = import_record.import_items.ordered.to_a

        payload = {
          id: import_record.id,
          user_id: import_record.user_id,
          credit_card_id: import_record.credit_card_id,
          credit_card_name: import_record.credit_card.name,
          statement_id: import_record.statement_id,
          source_kind: import_record.source_kind,
          provider_key: import_record.provider_key,
          status: import_record.status,
          error_payload: import_record.error_payload,
          processing_started_at: import_record.processing_started_at,
          processing_finished_at: import_record.processing_finished_at,
          confirmed_at: import_record.confirmed_at,
          statement_draft: import_record.statement_payload,
          summary: import_record.summary_payload,
          items_count: items.size,
          missing_category_count: items.count(&:needs_category?),
          can_confirm: import_record.confirmable? && items.none?(&:needs_category?)
        }

        payload[:items] = items.map { |item| import_item(item) } if include_items
        payload
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
