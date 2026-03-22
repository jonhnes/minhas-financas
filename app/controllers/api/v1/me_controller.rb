module Api
  module V1
    class MeController < BaseController
      def show
        authorize current_user, policy_class: UserPolicy

        render json: {
          data: Api::V1::Serializers.user(current_user).merge(
            onboarding: {
              has_account: current_user.accounts.exists?,
              has_credit_card: current_user.credit_cards.exists?,
              completed: current_user.onboarding_completed?
            }
          )
        }
      end

      def update
        authorize current_user, policy_class: UserPolicy
        current_user.update!(me_params)

        render_resource current_user, serializer: Api::V1::Serializers.method(:user)
      end

      private

      def me_params
        permitted = params.require(:me).permit(:name, :timezone, :locale, :complete_onboarding)
        if ActiveModel::Type::Boolean.new.cast(permitted.delete(:complete_onboarding))
          permitted[:onboarding_completed_at] = Time.current
        end
        permitted
      end
    end
  end
end
