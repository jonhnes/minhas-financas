class User < ApplicationRecord
  TRANSACTIONS_TABLE_COLUMN_ORDER = %w[impact date description category source amount].freeze
  TRANSACTIONS_TABLE_SORT_KEYS = %w[occurred_on category_name].freeze
  TRANSACTIONS_TABLE_SORT_DIRECTIONS = %w[asc desc].freeze
  TRANSACTIONS_TABLE_IMPACT_MODES = %w[all normal third_party off_budget informational].freeze
  DEFAULT_TRANSACTIONS_TABLE_SORT = {
    "key" => "occurred_on",
    "direction" => "desc"
  }.freeze

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

  def merged_ui_preferences(next_preferences)
    (ui_preferences || {}).deep_stringify_keys.deep_merge(self.class.sanitize_ui_preferences_patch(next_preferences))
  end

  def self.sanitize_ui_preferences_patch(input)
    preferences = input.respond_to?(:to_unsafe_h) ? input.to_unsafe_h : input
    preferences = preferences.is_a?(Hash) ? preferences.deep_stringify_keys : {}
    transactions_table = preferences["transactions_table"]

    return {} unless transactions_table.is_a?(Hash)

    sanitized_transactions_table = {}

    if transactions_table.key?("column_order")
      sanitized_transactions_table["column_order"] = normalize_transactions_table_column_order(transactions_table["column_order"])
    end

    if transactions_table.key?("sort")
      sanitized_transactions_table["sort"] = normalize_transactions_table_sort(transactions_table["sort"])
    end

    if transactions_table.key?("impact_mode")
      sanitized_transactions_table["impact_mode"] = normalize_transactions_table_impact_mode(transactions_table["impact_mode"])
    end

    return {} if sanitized_transactions_table.empty?

    { "transactions_table" => sanitized_transactions_table }
  end

  def self.normalize_transactions_table_column_order(value)
    provided_columns = Array.wrap(value).map(&:to_s)
    normalized = provided_columns.select { |column| TRANSACTIONS_TABLE_COLUMN_ORDER.include?(column) }.uniq

    normalized + (TRANSACTIONS_TABLE_COLUMN_ORDER - normalized)
  end

  def self.normalize_transactions_table_sort(value)
    sort = value.is_a?(Hash) ? value.deep_stringify_keys : {}
    key = TRANSACTIONS_TABLE_SORT_KEYS.include?(sort["key"]) ? sort["key"] : DEFAULT_TRANSACTIONS_TABLE_SORT["key"]
    direction = TRANSACTIONS_TABLE_SORT_DIRECTIONS.include?(sort["direction"]) ? sort["direction"] : DEFAULT_TRANSACTIONS_TABLE_SORT["direction"]

    {
      "key" => key,
      "direction" => direction
    }
  end

  def self.normalize_transactions_table_impact_mode(value)
    impact_mode = value.to_s

    return impact_mode if TRANSACTIONS_TABLE_IMPACT_MODES.include?(impact_mode)

    "all"
  end

  private

  def apply_defaults
    self.timezone ||= "America/Sao_Paulo"
    self.locale ||= "pt-BR"
    self.ui_preferences ||= {}
  end
end
