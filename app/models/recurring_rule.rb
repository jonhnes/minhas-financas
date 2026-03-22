class RecurringRule < ApplicationRecord
  belongs_to :user
  belongs_to :account, optional: true
  belongs_to :credit_card, optional: true
  belongs_to :card_holder, optional: true
  belongs_to :category, optional: true

  has_many :transactions, dependent: :nullify

  enum :frequency, {
    weekly: "weekly",
    biweekly: "biweekly",
    monthly: "monthly",
    yearly: "yearly"
  }

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

  validates :frequency, :starts_on, :transaction_type, :impact_mode, :description, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :source_presence

  scope :active, -> { where(active: true) }

  def due_on?(date)
    return false if !active? || date < starts_on || (ends_on.present? && date > ends_on)

    case frequency
    when "weekly"
      ((date - starts_on).to_i % 7).zero?
    when "biweekly"
      ((date - starts_on).to_i % 14).zero?
    when "monthly"
      starts_on.day == date.day || (starts_on.end_of_month.day == starts_on.day && date == date.end_of_month)
    when "yearly"
      starts_on.month == date.month && starts_on.day == date.day
    else
      false
    end
  end

  def schedule_next_run!(reference_date = Time.zone.today)
    update!(next_run_on: self.class.next_due_date_for(self, reference_date))
  end

  def self.next_due_date_for(rule, reference_date = Time.zone.today)
    cursor = [rule.starts_on, reference_date].max
    366.times do
      return cursor if rule.due_on?(cursor)

      cursor += 1.day
    end
    nil
  end

  private

  def source_presence
    if account_id.blank? && credit_card_id.blank?
      errors.add(:base, "Selecione uma conta ou cartão")
      return
    end

    return unless account_id.present? && credit_card_id.present?

    errors.add(:base, "Use conta ou cartão, nunca ambos")
  end
end
