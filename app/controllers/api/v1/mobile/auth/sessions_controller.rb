module Api
  module V1
    module Mobile
      module Auth
        class SessionsController < Api::V1::Mobile::BaseController
          skip_forgery_protection

          def create
            user = User.find_for_database_authentication(email: sign_in_params[:email].to_s.strip.downcase)

            unless user&.valid_password?(sign_in_params[:password].to_s)
              return render json: { errors: ["E-mail ou senha inválidos"] }, status: :unauthorized
            end

            issued = MobileSession.issue_for!(
              user: user,
              platform: sign_in_params[:platform],
              device_label: sign_in_params[:device_label]
            )

            render json: {
              data: Api::V1::Serializers.mobile_auth_session(
                issued.fetch(:session),
                access_token: issued.fetch(:access_token),
                refresh_token: issued.fetch(:refresh_token)
              )
            }, status: :ok
          end

          private

          def sign_in_params
            params.require(:auth).permit(:email, :password, :platform, :device_label)
          end
        end
      end
    end
  end
end
