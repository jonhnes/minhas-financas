class CreditCard < ApplicationRecord
  belongs_to :user
  belongs_to :payment_account, class_name: "Account", optional: true, inverse_of: :credit_cards

  has_many :card_holders, dependent: :destroy
  has_many :imports, dependent: :restrict_with_exception
  has_many :statements, dependent: :restrict_with_exception
  has_many :transactions, dependent: :restrict_with_exception

  before_validation :normalize_last_four_digits

  validates :name, :closing_day, :due_day, presence: true
  validates :credit_limit_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :closing_day, :due_day, inclusion: { in: 1..31 }
  validates :last_four_digits, format: { with: /\A\d{4}\z/, message: "deve ter 4 dígitos" }, allow_blank: true

  scope :active, -> { where(active: true) }

  def cycle_total(reference_date = Time.zone.today, include_third_party: false)
    range = cycle_range(reference_date)
    scope = transactions.where(occurred_on: range)
    scope = scope.where.not(impact_mode: :third_party) unless include_third_party
    scope.sum(:amount_cents)
  end

  def current_statement
    statements.recent_first.first
  end

  def cycle_range(reference_date = Time.zone.today)
    reference_date = reference_date.to_date
    last_closing = last_closing_for(reference_date)
    next_closing = next_closing_for(reference_date)
    (last_closing + 1.day)..next_closing
  end

  def statement_period_for_due_date(due_date)
    due_date = due_date.to_date
    period_end_base = due_date.day > closing_day ? due_date : due_date.prev_month
    period_end = closing_on(period_end_base)
    previous_period_end = closing_on(period_end.prev_month)

    {
      period_start: previous_period_end + 1.day,
      period_end: period_end
    }
  end

  private

  def last_closing_for(reference_date)
    closing_month = reference_date.day <= closing_day ? reference_date.prev_month : reference_date
    closing_on(closing_month)
  end

  def next_closing_for(reference_date)
    closing_month = reference_date.day <= closing_day ? reference_date : reference_date.next_month
    closing_on(closing_month)
  end

  def closing_on(date)
    end_of_month = date.end_of_month.day
    Date.new(date.year, date.month, [closing_day, end_of_month].min)
  end

  def normalize_last_four_digits
    self.last_four_digits = last_four_digits.to_s.gsub(/\D/, "").last(4).presence
  end
end
