module Imports
  class ConfirmImport
    class InvalidImportError < StandardError; end

    def initialize(import:)
      @import = import
    end

    def call
      raise InvalidImportError, "Importação não está pronta para confirmação" unless import.confirmable?

      statement_attributes = normalized_statement_attributes
      existing_statement = existing_statement_for(statement_attributes)
      if existing_statement.present? && !reusable_existing_statement?(existing_statement)
        raise InvalidImportError, "Já existe uma fatura para este cartão e período"
      end

      validate_items!

      ActiveRecord::Base.transaction do
        existing_statement&.lock!
        statement_matches = statement_transaction_matches_for(existing_statement)
        statement = upsert_statement!(statement_attributes, existing_statement: existing_statement)

        import.import_items.ordered.find_each do |item|
          transaction = create_transaction_for(item, statement, statement_matches: statement_matches) unless item.ignored?
          item.update!(
            status: :imported,
            linked_transaction: transaction
          )
        end

        import.update!(
          statement: statement,
          status: :confirmed,
          confirmed_at: Time.current,
          processing_finished_at: Time.current
        )

        statement
      end
    end

    private

    attr_reader :import

    def normalized_statement_attributes
      payload = import.statement_payload.symbolize_keys
      {
        period_start: Date.parse(payload.fetch(:period_start).to_s),
        period_end: Date.parse(payload.fetch(:period_end).to_s),
        due_date: Date.parse(payload.fetch(:due_date).to_s),
        total_amount_cents: payload.fetch(:total_amount_cents).to_i,
        status: payload.fetch(:status, "open"),
        metadata: payload.fetch(:metadata, {})
      }
    end

    def validate_items!
      invalid_item = import.import_items.pending_confirmation.find(&:needs_category?)
      if invalid_item
        raise InvalidImportError, "Todos os itens não ignorados precisam de categoria antes da confirmação"
      end
    end

    def create_transaction_for(item, statement, statement_matches:)
      existing_statement_transaction = statement_matches[item.id]
      return existing_statement_transaction if existing_statement_transaction.present?

      return create_regular_transaction_for(item, statement) unless item.installment_active?

      transaction = reconcile_current_installment_transaction(item, statement)
      generate_future_installments_for(item)
      transaction
    end

    def create_regular_transaction_for(item, statement)
      existing_transaction = regular_transaction_for(item)
      return update_regular_transaction_from_import!(existing_transaction, item, statement: statement, import_item: item) if existing_transaction.present?

      import.user.transactions.create!(base_transaction_attributes(item, statement: statement, import_item: item))
    end

    def reconcile_current_installment_transaction(item, statement)
      existing_transaction = installment_transaction_for(item.installment_group_key, item.installment_number)

      if existing_transaction.present?
        unless reconcilable_existing_transaction?(existing_transaction)
          raise InvalidImportError,
            "Já existe a parcela #{item.installment_number}/#{item.installment_total} para esta compra."
        end

        return update_transaction_from_import!(
          existing_transaction,
          item,
          statement: statement,
          import_item: item,
          installment_number: item.installment_number,
          auto_generated: false
        )
      end

      import.user.transactions.create!(
        installment_transaction_attributes(
          item,
          installment_number: item.installment_number,
          statement: statement,
          import_item: item,
          auto_generated: false
        )
      )
    end

    def generate_future_installments_for(item)
      (item.installment_number + 1).upto(item.installment_total) do |installment_number|
        existing_transaction = installment_transaction_for(item.installment_group_key, installment_number)

        if existing_transaction.present?
          next unless reconcilable_existing_transaction?(existing_transaction)

          update_transaction_from_import!(
            existing_transaction,
            item,
            statement: nil,
            import_item: nil,
            installment_number: installment_number,
            auto_generated: true
          )
          next
        end

        import.user.transactions.create!(
          installment_transaction_attributes(
            item,
            installment_number: installment_number,
            statement: nil,
            import_item: nil,
            auto_generated: true
          )
        )
      end
    end

    def installment_transaction_attributes(item, installment_number:, statement:, import_item:, auto_generated:)
      base_transaction_attributes(
        item,
        statement: statement,
        import_item: import_item,
        auto_generated: auto_generated,
        occurred_on: Installments::Support.occurrence_on(
          purchase_occurred_on: item.purchase_occurred_on,
          installment_number: installment_number
        ),
        metadata: build_transaction_metadata(item, installment_number: installment_number, auto_generated: auto_generated),
        installment_group_key: item.installment_group_key,
        installment_number: installment_number,
        installment_total: item.installment_total,
        purchase_occurred_on: item.purchase_occurred_on
      )
    end

    def update_transaction_from_import!(transaction, item, statement:, import_item:, installment_number:, auto_generated:)
      transaction.update!(
        base_transaction_attributes(
          item,
          statement: statement,
          import_item: import_item,
          auto_generated: auto_generated,
          occurred_on: Installments::Support.occurrence_on(
            purchase_occurred_on: item.purchase_occurred_on,
            installment_number: installment_number
          ),
          metadata: transaction.metadata.merge(
            build_transaction_metadata(item, installment_number: installment_number, auto_generated: auto_generated)
          ),
          installment_group_key: item.installment_group_key,
          installment_number: installment_number,
          installment_total: item.installment_total,
          purchase_occurred_on: item.purchase_occurred_on
        )
      )
      transaction
    end

    def update_regular_transaction_from_import!(transaction, item, statement:, import_item:)
      transaction.update!(
        base_transaction_attributes(
          item,
          statement: statement,
          import_item: import_item,
          metadata: transaction.metadata.merge(build_transaction_metadata(item, installment_number: item.installment_number, auto_generated: false))
        )
      )
      transaction
    end

    def base_transaction_attributes(item, statement:, import_item:, auto_generated: false, occurred_on: item.occurred_on, metadata: nil, **extra_attributes)
      {
        credit_card: import.credit_card,
        card_holder: item.card_holder,
        category: item.category,
        statement: statement,
        import_item: import_item,
        transaction_type: :expense,
        impact_mode: item.impact_mode,
        amount_cents: item.amount_cents,
        occurred_on: occurred_on,
        description: transaction_description_for(item, auto_generated: auto_generated),
        canonical_merchant_name: item.canonical_merchant_name,
        metadata: metadata || build_transaction_metadata(item, installment_number: item.installment_number, auto_generated: auto_generated),
        auto_generated: auto_generated
      }.merge(extra_attributes)
    end

    def transaction_description_for(item, auto_generated:)
      return item.description unless auto_generated && item.installment_active?

      Installments::Support.future_installment_description(
        description: item.description,
        canonical_merchant_name: item.canonical_merchant_name
      )
    end

    def build_transaction_metadata(item, installment_number:, auto_generated:)
      item.metadata.deep_dup.merge(
        "import_id" => import.id,
        "import_item_id" => item.id,
        "provider_key" => import.provider_key,
        "raw_holder_name" => item.raw_holder_name
      ).tap do |metadata|
        metadata["generated_from_import_id"] = import.id if auto_generated

        next unless item.installment_active?

        metadata["installment"] = item.metadata.fetch("installment", {}).merge(
          "group_key" => item.installment_group_key,
          "current_number" => installment_number,
          "total_installments" => item.installment_total,
          "purchase_occurred_on" => item.purchase_occurred_on&.iso8601
        )
      end
    end

    def installment_transaction_for(group_key, installment_number)
      import.user.transactions.find_by(
        installment_group_key: group_key,
        installment_number: installment_number
      )
    end

    def regular_transaction_for(item)
      scope = import.user.transactions.where(
        credit_card: import.credit_card,
        statement_id: nil,
        import_item_id: nil,
        transaction_type: :expense,
        amount_cents: item.amount_cents,
        occurred_on: item.occurred_on,
        installment_group_key: nil
      )

      exact_matches = scope.where(canonical_merchant_name: item.canonical_merchant_name) if item.canonical_merchant_name.present?
      return exact_matches.sole if exact_matches&.one?
      return nil if exact_matches.present? && exact_matches.many?

      description_matches = scope.where(description: item.description)
      return description_matches.sole if description_matches.one?

      nil
    end

    def reconcilable_existing_transaction?(transaction)
      transaction.statement_id.blank? && transaction.import_item_id.blank?
    end

    def existing_statement_for(statement_attributes)
      import.credit_card.statements.find_by(
        credit_card_id: import.credit_card_id,
        period_start: statement_attributes[:period_start],
        period_end: statement_attributes[:period_end]
      )
    end

    def reusable_existing_statement?(statement)
      return false if statement.blank?

      import.bradesco_pdf? &&
        %w[open_statement final_statement].include?(import.document_kind) &&
        statement.document_kind == "open_statement"
    end

    def upsert_statement!(statement_attributes, existing_statement:)
      next_metadata = statement_attributes[:metadata].merge(
        "provider_key" => import.provider_key,
        "import_id" => import.id
      )

      if existing_statement.present?
        existing_statement.update!(
          statement_attributes.merge(metadata: existing_statement.metadata.merge(next_metadata))
        )
        return existing_statement
      end

      import.credit_card.statements.create!(
        statement_attributes.merge(metadata: next_metadata)
      )
    end

    def statement_transaction_matches_for(statement)
      return {} unless reusable_existing_statement?(statement)

      current_items = import.import_items.reject(&:ignored?)
      match_result = Imports::BradescoRecordMatcher.new(
        current_records: current_items,
        existing_records: statement.transactions.to_a
      ).call

      match_result.fetch(:matches).each_with_object({}) do |(item, transaction), memo|
        memo[item.id] = transaction
      end
    end
  end
end
