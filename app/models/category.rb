class Category < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :parent, class_name: "Category", optional: true

  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent
  has_many :budgets, dependent: :restrict_with_exception
  has_many :category_suggestion_rules, dependent: :nullify
  has_many :transactions, dependent: :nullify

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :root_only, -> { where(parent_id: nil) }
  scope :system_default, -> { where(system: true, user_id: nil) }

  def subcategory?
    parent_id.present?
  end
end
