class ImportItem < ApplicationRecord
  belongs_to :import
  belongs_to :linked_transaction, class_name: "Transaction", optional: true
  belongs_to :category, optional: true
  belongs_to :card_holder, optional: true

  enum :transaction_type, {
    expense: "expense"
  }

  enum :impact_mode, {
    normal: "normal",
    third_party: "third_party",
    off_budget: "off_budget",
    informational: "informational"
  }

  enum :status, {
    pending_review: "pending_review",
    imported: "imported"
  }

  validates :line_index, :occurred_on, :description, :transaction_type, :impact_mode, :status, presence: true
  validates :amount_cents, numericality: { only_integer: true }
  validate :installment_fields_consistency

  scope :ordered, -> { order(:line_index, :id) }
  scope :pending_confirmation, -> { where(ignored: false) }

  def needs_category?
    !ignored? && category_id.blank?
  end

  def installment_active?
    installment_detected? && installment_enabled?
  end

  private

  def installment_fields_consistency
    has_installment_fields = installment_group_key.present? || installment_number.present? || installment_total.present? || purchase_occurred_on.present?
    return unless installment_detected? || installment_enabled? || has_installment_fields

    if !installment_detected? && installment_enabled?
      errors.add(:installment_enabled, "não pode ser ativado sem detecção de parcelado")
    end

    if installment_group_key.blank? || installment_number.blank? || installment_total.blank? || purchase_occurred_on.blank?
      errors.add(:base, "Parcelado detectado exige grupo, número, total e data da compra")
      return
    end

    return if Installments::Support.valid_installment_numbers?(installment_number, installment_total)

    errors.add(:base, "Parcelado detectado precisa ter número e total válidos")
  end
end
