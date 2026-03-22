class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :account, optional: true
  belongs_to :credit_card, optional: true
  belongs_to :card_holder, optional: true
  belongs_to :category, optional: true
  belongs_to :recurring_rule, optional: true
  belongs_to :transfer_account, class_name: "Account", optional: true

  has_many :transaction_tags, class_name: "TransactionTag", foreign_key: :transaction_id, dependent: :destroy, inverse_of: :entry
  has_many :tags, through: :transaction_tags

  enum :transaction_type, {
    income: "income",
    expense: "expense",
    transfer: "transfer",
    adjustment: "adjustment"
  }

  enum :impact_mode, {
    normal: "normal",
    third_party: "third_party",
    off_budget: "off_budget",
    informational: "informational"
  }

  validates :transaction_type, :impact_mode, :occurred_on, :description, presence: true
  validates :amount_cents, numericality: { only_integer: true }
  validate :source_presence
  validate :transfer_consistency
  validate :category_presence_for_financial_transaction

  scope :chronological, -> { order(occurred_on: :desc, created_at: :desc) }
  scope :for_reports, -> { where.not(impact_mode: %w[third_party informational]) }

  def counts_towards_consolidated?
    normal? || off_budget?
  end

  def account_delta_cents
    return 0 unless account_id

    case transaction_type
    when "income", "adjustment"
      amount_cents
    when "expense"
      credit_card_id.present? ? 0 : -amount_cents
    when "transfer"
      -amount_cents
    else
      0
    end
  end

  def transfer_delta_cents
    return 0 unless transfer?

    amount_cents
  end

  private

  def source_presence
    if account_id.blank? && credit_card_id.blank?
      errors.add(:base, "Selecione uma conta ou cartão")
      return
    end

    return if transfer?
    return unless account_id.present? && credit_card_id.present?

    errors.add(:base, "Use conta ou cartão, nunca ambos")
  end

  def transfer_consistency
    if transfer?
      errors.add(:transfer_account, "é obrigatória") if transfer_account_id.blank?
      errors.add(:account, "é obrigatória") if account_id.blank?
      errors.add(:credit_card, "não pode ser usado em transferência") if credit_card_id.present?
    elsif transfer_account_id.present?
      errors.add(:transfer_account, "só pode ser usada em transferências")
    end
  end

  def category_presence_for_financial_transaction
    return if transfer?
    return if category_id.present?

    errors.add(:category, "é obrigatória")
  end
end
