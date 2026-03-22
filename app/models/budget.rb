class Budget < ApplicationRecord
  belongs_to :user
  belongs_to :category
  belongs_to :subcategory, class_name: "Category", optional: true

  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :period_type, inclusion: { in: ["monthly"] }

  scope :active, -> { where(active: true) }
end
