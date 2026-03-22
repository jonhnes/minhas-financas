class CardHolderPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    owner?
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
      scope.joins(:credit_card).where(credit_cards: { user_id: user.id })
    end
  end

  private

  def owner?
    record.credit_card.user == user
  end
end
