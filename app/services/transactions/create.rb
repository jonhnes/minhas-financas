module Transactions
  class Create
    def initialize(transaction:, installment: nil)
      @transaction = transaction
      @installment = normalize_installment(installment)
      @base_metadata = (transaction.metadata || {}).deep_dup
    end

    def call
      ActiveRecord::Base.transaction do
        return save_single_transaction! unless installment_enabled?

        prepare_current_installment!
        transaction.save!
        generate_future_installments! if generate_future_installments?
        transaction
      end
    end

    private

    attr_reader :base_metadata, :installment, :transaction

    def normalize_installment(payload)
      return {} if payload.blank?

      raw_payload = payload.respond_to?(:to_h) ? payload.to_h : payload
      raw_payload.symbolize_keys
    end

    def save_single_transaction!
      transaction.save!
      transaction
    end

    def installment_enabled?
      ActiveModel::Type::Boolean.new.cast(installment[:enabled])
    end

    def generate_future_installments?
      installment_enabled? && ActiveModel::Type::Boolean.new.cast(installment[:generate_future_installments])
    end

    def prepare_current_installment!
      validate_installment_payload!
      validate_missing_existing_installment!(current_installment_number)

      transaction.assign_attributes(
        occurred_on: Installments::Support.occurrence_on(
          purchase_occurred_on: purchase_occurred_on,
          installment_number: current_installment_number
        ),
        installment_group_key: installment_group_key,
        installment_number: current_installment_number,
        installment_total: total_installments,
        purchase_occurred_on: purchase_occurred_on,
        metadata: installment_metadata_for(current_installment_number)
      )
    end

    def validate_installment_payload!
      unless transaction.expense?
        transaction.errors.add(:base, "Parcelamento só pode ser usado em despesas")
      end

      if transaction.credit_card.blank?
        transaction.errors.add(:credit_card, "é obrigatório para transação parcelada")
      end

      if transaction.account.present?
        transaction.errors.add(:account, "não pode ser usado em transação parcelada no cartão")
      end

      if purchase_occurred_on.blank?
        transaction.errors.add(:base, "Data da compra é obrigatória para parcelamento")
      end

      unless Installments::Support.valid_installment_numbers?(current_installment_number, total_installments)
        transaction.errors.add(:base, "Parcelamento precisa ter número e total válidos")
      end

      raise ActiveRecord::RecordInvalid, transaction if transaction.errors.any?
    end

    def installment_group_key
      @installment_group_key ||= Installments::Support.group_key(
        credit_card_id: transaction.credit_card_id,
        canonical_merchant_name: installment_merchant_name,
        purchase_occurred_on: purchase_occurred_on,
        amount_cents: transaction.amount_cents,
        installment_total: total_installments
      )
    end

    def installment_merchant_name
      transaction.canonical_merchant_name.presence ||
        Installments::Support.description_without_installment_marker(transaction.description)
    end

    def purchase_occurred_on
      @purchase_occurred_on ||= begin
        value = installment[:purchase_occurred_on].presence || transaction.occurred_on
        value.respond_to?(:to_date) ? value.to_date : Date.parse(value.to_s)
      rescue Date::Error
        nil
      end
    end

    def current_installment_number
      installment[:current_number].to_i
    end

    def total_installments
      installment[:total_installments].to_i
    end

    def generate_future_installments!
      (current_installment_number + 1).upto(total_installments) do |installment_number|
        validate_missing_existing_installment!(installment_number)

        transaction.user.transactions.create!(
          future_installment_attributes(installment_number)
        )
      end
    end

    def future_installment_attributes(installment_number)
      {
        account: nil,
        credit_card: transaction.credit_card,
        card_holder: transaction.card_holder,
        category: transaction.category,
        transaction_type: transaction.transaction_type,
        impact_mode: transaction.impact_mode,
        amount_cents: transaction.amount_cents,
        occurred_on: Installments::Support.occurrence_on(
          purchase_occurred_on: purchase_occurred_on,
          installment_number: installment_number
        ),
        description: Installments::Support.future_installment_description(
          description: transaction.description,
          canonical_merchant_name: transaction.canonical_merchant_name
        ),
        canonical_merchant_name: transaction.canonical_merchant_name,
        metadata: installment_metadata_for(installment_number),
        auto_generated: true,
        installment_group_key: installment_group_key,
        installment_number: installment_number,
        installment_total: total_installments,
        purchase_occurred_on: purchase_occurred_on
      }
    end

    def installment_metadata_for(installment_number)
      base_metadata.deep_dup.tap do |metadata|
        metadata["installment"] = metadata.fetch("installment", {}).merge(
          "group_key" => installment_group_key,
          "current_number" => installment_number,
          "total_installments" => total_installments,
          "purchase_occurred_on" => purchase_occurred_on&.iso8601
        )
      end
    end

    def validate_missing_existing_installment!(installment_number)
      existing_transaction = transaction.user.transactions.find_by(
        installment_group_key: installment_group_key,
        installment_number: installment_number
      )
      return if existing_transaction.blank?

      existing_transaction.errors.add(:base, "Já existe a parcela #{installment_number}/#{total_installments} para esta compra.")
      raise ActiveRecord::RecordInvalid, existing_transaction
    end
  end
end
