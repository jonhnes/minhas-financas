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
        current_user.assign_attributes(me_params.except(:ui_preferences))
        current_user.ui_preferences = current_user.merged_ui_preferences(me_params[:ui_preferences]) if me_params[:ui_preferences].present?
        current_user.save!

        render_resource current_user, serializer: Api::V1::Serializers.method(:user)
      end

      private

      def me_params
        raw_params = params.require(:me)
        permitted = raw_params.permit(:name, :timezone, :locale, :complete_onboarding)
        permitted[:ui_preferences] = raw_params[:ui_preferences] if raw_params.key?(:ui_preferences)

        if ActiveModel::Type::Boolean.new.cast(permitted.delete(:complete_onboarding))
          permitted[:onboarding_completed_at] = Time.current
        end

        permitted
      end
    end
  end
end
