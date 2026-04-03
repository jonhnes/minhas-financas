class CategorySuggestionRule < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true

  enum :match_type, {
    contains: "contains",
    starts_with: "starts_with",
    ends_with: "ends_with"
  }

  validates :match_type, :pattern, :normalized_pattern, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :category_presence
  validate :category_is_active

  before_validation :normalize_pattern
  before_validation :assign_default_position, on: :create

  scope :active, -> { where(active: true) }

  def applies_to?(text)
    normalized_text = CategorySuggestions::TextNormalizer.normalize(text)
    return false if normalized_text.blank? || normalized_pattern.blank?

    case match_type
    when "starts_with"
      normalized_text.start_with?(normalized_pattern)
    when "ends_with"
      normalized_text.end_with?(normalized_pattern)
    else
      normalized_text.include?(normalized_pattern)
    end
  end

  private

  def normalize_pattern
    self.normalized_pattern = CategorySuggestions::TextNormalizer.normalize(pattern)
  end

  def assign_default_position
    return unless position.blank? && user.present?

    self.position = user.category_suggestion_rules.maximum(:position).to_i + 1
  end

  def category_presence
    errors.add(:category, "é obrigatória") if category_id.blank?
  end

  def category_is_active
    return if category.blank? || category.active?

    errors.add(:category, "precisa estar ativa")
  end
end
