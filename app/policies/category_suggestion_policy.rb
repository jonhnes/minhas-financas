class CategorySuggestionPolicy < ApplicationPolicy
  def create?
    user.present?
  end
end
