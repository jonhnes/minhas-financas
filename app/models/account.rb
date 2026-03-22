class Account < ApplicationRecord
  belongs_to :user

  has_many :credit_cards, foreign_key: :payment_account_id, dependent: :nullify, inverse_of: :payment_account
  has_many :transactions, dependent: :restrict_with_exception
  has_many :incoming_transfers, class_name: "Transaction", foreign_key: :transfer_account_id, dependent: :nullify, inverse_of: :transfer_account

  enum :kind, {
    checking: "checking",
    savings: "savings",
    cash: "cash",
    wallet: "wallet",
    digital: "digital"
  }

  validates :kind, :name, presence: true
  validates :initial_balance_cents, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }

  def current_balance
    initial_balance_cents + posted_delta
  end

  private

  def posted_delta
    transactions.sum(&:account_delta_cents) + incoming_transfers.sum(&:transfer_delta_cents)
  end
end
