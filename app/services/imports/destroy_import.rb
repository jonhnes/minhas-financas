module Imports
  class DestroyImport
    class DestroyError < StandardError; end

    def initialize(import:)
      @import = import
    end

    def call
      Import.transaction do
        import.lock!

        if import.confirmed?
          destroy_confirmed_import!
        else
          import.destroy!
        end
      end
    end

    private

    attr_reader :import

    def destroy_confirmed_import!
      statement = import.statement
      linked_transactions = import.import_items.includes(:linked_transaction).filter_map(&:linked_transaction)
      generated_future_transactions = import.user.transactions.where(
        auto_generated: true,
        import_item_id: nil
      ).where("metadata ->> 'generated_from_import_id' = ?", import.id.to_s).to_a

      ensure_safe_statement_rollback!(statement, linked_transactions)

      import.import_items.update_all(linked_transaction_id: nil, updated_at: Time.current)
      linked_transactions.each(&:destroy!)
      generated_future_transactions.each(&:destroy!)
      import.update!(statement: nil)
      import.destroy!
      statement&.destroy!
    end

    def ensure_safe_statement_rollback!(statement, linked_transactions)
      return unless statement

      if statement.imports.where.not(id: import.id).exists?
        raise DestroyError, "Não foi possível apagar a importação porque esta fatura também está vinculada a outra importação."
      end

      linked_transaction_ids = linked_transactions.map(&:id).sort
      statement_transaction_ids = statement.transactions.pluck(:id).sort

      return if linked_transaction_ids == statement_transaction_ids

      raise DestroyError,
        "Não foi possível apagar a importação porque a fatura já possui lançamentos fora desta importação."
    end
  end
end
