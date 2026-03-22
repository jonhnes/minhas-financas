class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :accounts, dependent: :destroy
  has_many :budgets, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :credit_cards, dependent: :destroy
  has_many :imports, dependent: :destroy
  has_many :recurring_rules, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :transactions, dependent: :destroy

  validates :name, :timezone, :locale, presence: true

  before_validation :apply_defaults

  def onboarding_completed?
    onboarding_completed_at.present?
  end

  private

  def apply_defaults
    self.timezone ||= "America/Sao_Paulo"
    self.locale ||= "pt-BR"
  end
end
