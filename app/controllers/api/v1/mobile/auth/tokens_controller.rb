module Api
  module V1
    module Mobile
      module Auth
        class TokensController < Api::V1::Mobile::BaseController
          skip_forgery_protection only: :create
          before_action :authenticate_mobile_session!, only: :destroy

          def create
            session = MobileSession.find_by_refresh_token(refresh_params[:refresh_token])

            unless session.present?
              return render json: { errors: ["Refresh token inválido ou expirado"] }, status: :unauthorized
            end

            rotated = session.rotate_tokens!

            render json: {
              data: Api::V1::Serializers.mobile_auth_session(
                session,
                access_token: rotated.fetch(:access_token),
                refresh_token: rotated.fetch(:refresh_token)
              )
            }, status: :ok
          end

          def destroy
            current_mobile_session.revoke!
            render json: { data: { signed_out: true } }, status: :ok
          end

          private

          def refresh_params
            params.require(:auth).permit(:refresh_token)
          end
        end
      end
    end
  end
end
