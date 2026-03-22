class Tag < ApplicationRecord
  belongs_to :user

  has_many :transaction_tags, class_name: "TransactionTag", dependent: :destroy, inverse_of: :tag
  has_many :transactions, through: :transaction_tags, source: :entry

  validates :name, presence: true
end
