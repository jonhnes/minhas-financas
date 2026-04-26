module Imports
  class SyncBradescoReview
    PREVIEW_MATCH_STATUSES = {
      statement: "matched_existing_statement_transaction",
      unattached: "matched_unattached_transaction",
      new_item: "new_item"
    }.freeze
    REFRESHABLE_DOCUMENT_KINDS = %w[open_statement final_statement].freeze

    def initialize(import:)
      @import = import
    end

    def call
      return import unless import.bradesco_pdf?
      return import unless import.review_pending?

      Import.transaction do
        reset_preview_matches!

        replaced_open_draft = replace_open_draft_if_needed!
        statement_match_payload = sync_existing_statement_comparison_if_needed!
        sync_unattached_transaction_matches!
        persist_comparison_payload!(statement_match_payload:, replaced_open_draft:)
      end

      import
    end

    private

    attr_reader :import

    def replace_open_draft_if_needed!
      return nil unless REFRESHABLE_DOCUMENT_KINDS.include?(import.document_kind)

      open_drafts = same_period_imports.select do |candidate|
        candidate.review_pending? && candidate.document_kind == "open_statement"
      end
      return nil if open_drafts.empty?

      source_import = open_drafts.max_by(&:created_at)
      match_result = Imports::BradescoRecordMatcher.new(
        current_records: import.import_items.to_a,
        existing_records: source_import.import_items.to_a
      ).call

      match_result.fetch(:matches).each do |current_item, source_item|
        copy_review_adjustments!(current_item:, source_item:)
      end

      open_drafts.each { |draft| draft.update!(status: :superseded) }

      {
        mode: import.document_kind == "final_statement" ? "replacing_open_draft" : "refreshing_open_draft",
        source_import_id: source_import.id,
        matched_existing_count: match_result.fetch(:matches).size,
        new_items_count: import.import_items.size - match_result.fetch(:matches).size
      }
    end

    def sync_existing_statement_comparison_if_needed!
      return nil unless REFRESHABLE_DOCUMENT_KINDS.include?(import.document_kind)

      statement = matching_statement
      return nil unless statement&.document_kind == "open_statement"

      current_items = import.import_items.reject(&:ignored?)
      match_result = Imports::BradescoRecordMatcher.new(
        current_records: current_items,
        existing_records: statement.transactions.to_a
      ).call

      match_result.fetch(:matches).each do |current_item, transaction|
        mark_preview_match!(item: current_item, status: PREVIEW_MATCH_STATUSES[:statement], transaction: transaction)
      end

      unmatched_transactions = match_result.fetch(:unmatched_existing)

      {
        mode: import.document_kind == "final_statement" ? "finalizing_existing_open_statement" : "refreshing_existing_open_statement",
        existing_statement_id: statement.id,
        matched_existing_count: match_result.fetch(:matches).size,
        new_items_count: current_items.size - match_result.fetch(:matches).size,
        missing_from_final_count: unmatched_transactions.size,
        missing_from_final_transactions: unmatched_transactions.map { |transaction| missing_transaction_payload(transaction) }
      }
    end

    def sync_unattached_transaction_matches!
      existing_statement_transaction_ids = import.import_items.filter_map { |item| item.metadata["matched_transaction_id"] }

      unmatched_items = import.import_items.reject(&:ignored?).select { |item| item.comparison_status == PREVIEW_MATCH_STATUSES[:new_item] }
      return if unmatched_items.empty?

      unattached_scope = import.user.transactions.where(
        credit_card: import.credit_card,
        statement_id: nil,
        import_item_id: nil,
        transaction_type: :expense
      )
      unattached_scope = unattached_scope.where.not(id: existing_statement_transaction_ids) if existing_statement_transaction_ids.any?

      match_result = Imports::BradescoRecordMatcher.new(
        current_records: unmatched_items,
        existing_records: unattached_scope.to_a
      ).call

      match_result.fetch(:matches).each do |current_item, transaction|
        mark_preview_match!(item: current_item, status: PREVIEW_MATCH_STATUSES[:unattached], transaction: transaction)
      end
    end

    def persist_comparison_payload!(statement_match_payload:, replaced_open_draft:)
      payload =
        if statement_match_payload.present?
          statement_match_payload
        elsif replaced_open_draft.present?
          {
            mode: replaced_open_draft.fetch(:mode),
            existing_statement_id: nil,
            matched_existing_count: replaced_open_draft.fetch(:matched_existing_count),
            new_items_count: replaced_open_draft.fetch(:new_items_count),
            missing_from_final_count: 0,
            missing_from_final_transactions: []
          }
        end

      next_payload = import.parsed_payload.deep_dup
      if payload.present?
        next_payload["comparison"] = payload
      else
        next_payload.delete("comparison")
      end

      import.update!(parsed_payload: next_payload)
    end

    def mark_preview_match!(item:, status:, transaction:)
      item.update!(
        transaction_review_attributes(transaction).merge(
          metadata: item.metadata.merge(
            "comparison_status" => status,
            "matched_transaction_id" => transaction.id
          )
        )
      )
    end

    def transaction_review_attributes(transaction)
      {
        occurred_on: transaction.occurred_on,
        description: transaction.description,
        amount_cents: transaction.amount_cents,
        card_holder: transaction.card_holder,
        category: transaction.category,
        impact_mode: transaction.impact_mode,
        canonical_merchant_name: transaction.canonical_merchant_name
      }
    end

    def reset_preview_matches!
      import.import_items.find_each do |item|
        next unless item.metadata.key?("comparison_status") || item.metadata.key?("matched_transaction_id")

        item.update!(
          metadata: item.metadata.except("comparison_status", "matched_transaction_id")
        )
      end

      import.import_items.where(ignored: false).find_each do |item|
        next if item.metadata["comparison_status"] == PREVIEW_MATCH_STATUSES[:new_item]

        item.update!(
          metadata: item.metadata.merge("comparison_status" => PREVIEW_MATCH_STATUSES[:new_item]).except("matched_transaction_id")
        )
      end
    end

    def copy_review_adjustments!(current_item:, source_item:)
      current_item.update!(
        occurred_on: source_item.occurred_on,
        description: source_item.description,
        amount_cents: source_item.amount_cents,
        card_holder: source_item.card_holder,
        category: source_item.category,
        impact_mode: source_item.impact_mode,
        ignored: source_item.ignored,
        installment_enabled: source_item.installment_enabled
      )
    end

    def same_period_imports
      import.user.imports
        .includes(:import_items)
        .where(credit_card: import.credit_card)
        .where.not(id: import.id)
        .select do |candidate|
          candidate.statement_payload["period_start"] == import.statement_payload["period_start"] &&
            candidate.statement_payload["period_end"] == import.statement_payload["period_end"]
        end
    end

    def matching_statement
      import.credit_card.statements.find_by(
        period_start: import.statement_payload["period_start"],
        period_end: import.statement_payload["period_end"]
      )
    end

    def missing_transaction_payload(transaction)
      {
        transaction_id: transaction.id,
        occurred_on: transaction.occurred_on,
        description: transaction.description,
        amount_cents: transaction.amount_cents,
        card_holder_name: transaction.card_holder&.name
      }
    end
  end
end
