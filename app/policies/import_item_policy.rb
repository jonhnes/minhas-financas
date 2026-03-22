class ImportItemPolicy < ApplicationPolicy
  def update?
    owner?
  end

  class Scope < Scope
    def resolve
      scope.joins(:import).where(imports: { user_id: user.id })
    end
  end

  private

  def owner?
    record.import.user == user
  end
end
