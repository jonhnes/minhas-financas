module Imports
  class ConfirmImport
    class InvalidImportError < StandardError; end

    def initialize(import:)
      @import = import
    end

    def call
      raise InvalidImportError, "Importação não está pronta para confirmação" unless import.confirmable?

      statement_attributes = normalized_statement_attributes
      if import.credit_card.statements.exists?(credit_card_id: import.credit_card_id, period_start: statement_attributes[:period_start], period_end: statement_attributes[:period_end])
        raise InvalidImportError, "Já existe uma fatura para este cartão e período"
      end

      validate_items!

      ActiveRecord::Base.transaction do
        statement = import.credit_card.statements.create!(
          statement_attributes.merge(
            metadata: statement_attributes[:metadata].merge(
              "provider_key" => import.provider_key,
              "import_id" => import.id
            )
          )
        )

        import.import_items.ordered.find_each do |item|
          transaction = create_transaction_for(item, statement) unless item.ignored?
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
      return unless invalid_item

      raise InvalidImportError, "Todos os itens não ignorados precisam de categoria antes da confirmação"
    end

    def create_transaction_for(item, statement)
      import.user.transactions.create!(
        credit_card: import.credit_card,
        card_holder: item.card_holder,
        category: item.category,
        statement: statement,
        import_item: item,
        transaction_type: :expense,
        impact_mode: item.impact_mode,
        amount_cents: item.amount_cents,
        occurred_on: item.occurred_on,
        description: item.description,
        canonical_merchant_name: item.canonical_merchant_name,
        metadata: item.metadata.merge(
          "import_id" => import.id,
          "import_item_id" => item.id,
          "provider_key" => import.provider_key,
          "raw_holder_name" => item.raw_holder_name
        )
      )
    end
  end
end
