class CategoryPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    system_category? || owner?
  end

  def create?
    user.present?
  end

  def update?
    owner?
  end

  def destroy?
    owner?
  end

  class Scope < Scope
    def resolve
      scope.where("user_id = ? OR (user_id IS NULL AND system = ?)", user.id, true)
    end
  end

  private

  def owner?
    record.user == user
  end

  def system_category?
    record.system? && record.user_id.nil?
  end
end
