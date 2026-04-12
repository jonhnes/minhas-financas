module Imports
  class BradescoRecordMatcher
    def initialize(current_records:, existing_records:)
      @current_records = current_records.sort_by { |record| sort_key_for(record) }
      @existing_records = existing_records.sort_by { |record| sort_key_for(record) }
    end

    def call
      remaining_records = existing_records.dup
      matches = {}

      current_records.each do |current_record|
        candidate = find_candidate_for(current_record, remaining_records)
        next unless candidate

        matches[current_record] = candidate
        remaining_records.delete(candidate)
      end

      {
        matches: matches,
        unmatched_existing: remaining_records
      }
    end

    private

    attr_reader :current_records, :existing_records

    def find_candidate_for(current_record, remaining_records)
      installment_key = installment_key_for(current_record)
      if installment_key.present?
        candidate = remaining_records.find do |existing_record|
          installment_key_for(existing_record) == installment_key
        end
        return candidate if candidate
      end

      regular_signature = regular_signature_for(current_record)
      return nil if regular_signature.blank?

      candidate = remaining_records.find do |existing_record|
        regular_signature_match_with_canonical?(regular_signature, regular_signature_for(existing_record))
      end
      return candidate if candidate

      remaining_records.find do |existing_record|
        regular_signature_match_with_description?(regular_signature, regular_signature_for(existing_record))
      end
    end

    def sort_key_for(record)
      [
        record.try(:line_index) || Float::INFINITY,
        record.try(:occurred_on)&.iso8601 || "",
        record.try(:amount_cents).to_i,
        record.try(:description).to_s,
        record.try(:id) || 0
      ]
    end

    def installment_key_for(record)
      metadata = parsed_identity_for(record)
      group_key = metadata["installment_group_key"].presence || record.try(:installment_group_key).presence
      installment_number = metadata["installment_number"].presence || record.try(:installment_number).presence
      return nil if group_key.blank? || installment_number.blank?

      [group_key, installment_number.to_i]
    end

    def regular_signature_for(record)
      metadata = parsed_identity_for(record)

      {
        occurred_on: (metadata["occurred_on"].presence || record.try(:occurred_on)&.iso8601),
        amount_cents: (metadata.key?("amount_cents") ? metadata["amount_cents"].to_i : record.try(:amount_cents).to_i),
        canonical_merchant_name: metadata["canonical_merchant_name"].presence || record.try(:canonical_merchant_name).presence,
        description: metadata["description"].presence || record.try(:description).presence
      }
    end

    def parsed_identity_for(record)
      record.try(:metadata).to_h.fetch("parsed_identity", {})
    end

    def regular_signature_match_with_canonical?(left, right)
      return false unless same_amount_and_date?(left, right)
      return false if left[:canonical_merchant_name].blank? || right[:canonical_merchant_name].blank?

      left[:canonical_merchant_name] == right[:canonical_merchant_name]
    end

    def regular_signature_match_with_description?(left, right)
      same_amount_and_date?(left, right) && left[:description].present? && left[:description] == right[:description]
    end

    def same_amount_and_date?(left, right)
      left[:occurred_on].present? &&
        left[:occurred_on] == right[:occurred_on] &&
        left[:amount_cents].to_i == right[:amount_cents].to_i
    end
  end
end
