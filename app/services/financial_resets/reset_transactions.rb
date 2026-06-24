module FinancialResets
  class ResetTransactions
    class ConfirmationRequiredError < StandardError; end

    def initialize(user:, dry_run: true, confirmed: false)
      @user = user
      @dry_run = dry_run.nil? ? true : ActiveModel::Type::Boolean.new.cast(dry_run)
      @confirmed = ActiveModel::Type::Boolean.new.cast(confirmed)
    end

    def call
      raise ConfirmationRequiredError, "Confirmação explícita é obrigatória para executar o reset" if !dry_run && !confirmed

      backup = backup_payload
      before = summary_counts
      blob_ids = import_blob_ids

      ActiveRecord::Base.transaction do
        remove_financial_history!
        raise ActiveRecord::Rollback if dry_run
      end

      ActiveStorage::Blob.where(id: blob_ids).find_each(&:purge) unless dry_run

      {
        dry_run: dry_run,
        deleted: !dry_run,
        before: before,
        after: summary_counts,
        backup: backup
      }
    end

    private

    attr_reader :user, :dry_run, :confirmed

    def remove_financial_history!
      TransactionTag.where(transaction_id: transaction_ids).delete_all
      Transaction.where(id: transaction_ids).update_all(import_item_id: nil, statement_id: nil)
      ImportItem.where(id: import_item_ids).update_all(linked_transaction_id: nil)

      Transaction.where(id: transaction_ids).delete_all
      ImportItem.where(id: import_item_ids).delete_all
      ActiveStorage::Attachment.where(record_type: "Import", record_id: import_ids).delete_all
      Import.where(id: import_ids).delete_all
      Statement.where(id: statement_ids).delete_all
      user.accounts.update_all(initial_balance_cents: 0, updated_at: Time.current)
    end

    def backup_payload
      {
        generated_at: Time.current.iso8601,
        user: Api::V1::Serializers.user(user),
        transactions: transactions.order(:id).map(&:attributes),
        transaction_tags: TransactionTag.where(transaction_id: transaction_ids).order(:id).map(&:attributes),
        imports: imports.order(:id).map(&:attributes),
        import_items: ImportItem.where(id: import_item_ids).order(:id).map(&:attributes),
        statements: Statement.where(id: statement_ids).order(:id).map(&:attributes),
        accounts_before: user.accounts.order(:id).map(&:attributes),
        active_storage_attachments: ActiveStorage::Attachment.where(record_type: "Import", record_id: import_ids).order(:id).map(&:attributes),
        active_storage_blobs: ActiveStorage::Blob.where(id: import_blob_ids).order(:id).map(&:attributes)
      }
    end

    def summary_counts
      {
        transactions: transactions.count,
        transaction_tags: TransactionTag.where(transaction_id: transaction_ids).count,
        imports: imports.count,
        import_items: ImportItem.where(import_id: import_ids).count,
        statements: Statement.where(id: statement_ids).count,
        accounts: user.accounts.count,
        accounts_with_nonzero_initial_balance: user.accounts.where.not(initial_balance_cents: 0).count,
        account_balances: user.accounts.order(:id).map do |account|
          {
            id: account.id,
            name: account.name,
            initial_balance_cents: account.initial_balance_cents,
            current_balance_cents: account.current_balance
          }
        end
      }
    end

    def transactions
      user.transactions
    end

    def imports
      user.imports
    end

    def transaction_ids
      @transaction_ids ||= transactions.pluck(:id)
    end

    def import_ids
      @import_ids ||= imports.pluck(:id)
    end

    def import_item_ids
      @import_item_ids ||= ImportItem.where(import_id: import_ids).pluck(:id)
    end

    def statement_ids
      @statement_ids ||= Statement.where(credit_card_id: user.credit_cards.select(:id)).pluck(:id)
    end

    def import_blob_ids
      @import_blob_ids ||= ActiveStorage::Attachment.where(record_type: "Import", record_id: import_ids).pluck(:blob_id)
    end
  end
end
