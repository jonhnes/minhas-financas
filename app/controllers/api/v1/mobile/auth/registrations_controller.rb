module Api
  module V1
    module Mobile
      module Auth
        class RegistrationsController < Api::V1::Mobile::BaseController
          skip_forgery_protection

          def create
            user = User.new(sign_up_params)

            if user.save
              issued = MobileSession.issue_for!(
                user: user,
                platform: device_params[:platform],
                device_label: device_params[:device_label]
              )

              render json: {
                data: Api::V1::Serializers.mobile_auth_session(
                  issued.fetch(:session),
                  access_token: issued.fetch(:access_token),
                  refresh_token: issued.fetch(:refresh_token)
                )
              }, status: :created
            else
              render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def sign_up_params
            params.require(:user).permit(:name, :email, :password, :password_confirmation, :timezone, :locale)
          end

          def device_params
            params.fetch(:device, ActionController::Parameters.new).permit(:platform, :device_label)
          end
        end
      end
    end
  end
end
