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

  scope :ordered, -> { order(:line_index, :id) }
  scope :pending_confirmation, -> { where(ignored: false) }

  def needs_category?
    !ignored? && category_id.blank?
  end
end
