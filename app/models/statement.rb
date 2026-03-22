class Statement < ApplicationRecord
  belongs_to :credit_card

  has_many :imports, dependent: :restrict_with_exception
  has_many :transactions, dependent: :restrict_with_exception

  enum :status, {
    open: "open",
    closed: "closed"
  }

  validates :period_start, :period_end, :due_date, :status, presence: true
  validates :total_amount_cents, numericality: { only_integer: true }
  validate :period_consistency

  scope :recent_first, -> { order(due_date: :desc, period_end: :desc) }

  def display_name
    "#{credit_card.name} · #{I18n.l(period_end, format: "%B/%Y")}"
  end

  private

  def period_consistency
    return if period_start.blank? || period_end.blank?
    return if period_start <= period_end

    errors.add(:period_end, "deve ser igual ou posterior ao início")
  end
end
