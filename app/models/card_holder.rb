class CardHolder < ApplicationRecord
  belongs_to :credit_card

  has_many :transactions, dependent: :nullify

  enum :holder_type, {
    owner: "owner",
    additional: "additional"
  }

  validates :name, :holder_type, presence: true
end
