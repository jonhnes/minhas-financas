require "digest"

module Installments
  module Support
    module_function

    def normalize_merchant_name(name)
      ActiveSupport::Inflector.transliterate(name.to_s).upcase.gsub(/\s+/, " ").strip
    end

    def group_key(credit_card_id:, canonical_merchant_name:, purchase_occurred_on:, amount_cents:, installment_total:)
      return if credit_card_id.blank? || canonical_merchant_name.blank? || purchase_occurred_on.blank? || amount_cents.blank? || installment_total.blank?

      normalized_name = normalize_merchant_name(canonical_merchant_name)
      raw_key = [
        credit_card_id,
        normalized_name,
        purchase_occurred_on.to_date.iso8601,
        amount_cents.to_i,
        installment_total.to_i
      ].join(":")

      Digest::SHA256.hexdigest(raw_key)
    end

    def occurrence_on(purchase_occurred_on:, installment_number:)
      return if purchase_occurred_on.blank? || installment_number.blank?

      purchase_occurred_on.to_date >> (installment_number.to_i - 1)
    end

    def build_import_item_attributes(credit_card_id:, canonical_merchant_name:, purchase_occurred_on:, amount_cents:, installment_number:, installment_total:)
      return default_import_item_attributes unless valid_installment_numbers?(installment_number, installment_total)

      purchase_date = purchase_occurred_on.to_date
      {
        installment_detected: true,
        installment_enabled: true,
        installment_group_key: group_key(
          credit_card_id: credit_card_id,
          canonical_merchant_name: canonical_merchant_name,
          purchase_occurred_on: purchase_date,
          amount_cents: amount_cents,
          installment_total: installment_total
        ),
        installment_number: installment_number.to_i,
        installment_total: installment_total.to_i,
        purchase_occurred_on: purchase_date,
        occurred_on: occurrence_on(
          purchase_occurred_on: purchase_date,
          installment_number: installment_number
        )
      }
    end

    def default_import_item_attributes
      {
        installment_detected: false,
        installment_enabled: false,
        installment_group_key: nil,
        installment_number: nil,
        installment_total: nil,
        purchase_occurred_on: nil
      }
    end

    def valid_installment_numbers?(installment_number, installment_total)
      current = installment_number.to_i
      total = installment_total.to_i

      current.positive? && total.positive? && current <= total
    end
  end
end
