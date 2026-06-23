module Api
  module V1
    module Mcp
      class BrowserAuthController < BaseController
        skip_forgery_protection only: :token
        skip_before_action :authenticate_api_user!, only: :token

        def create
          grant, code = McpBrowserAuthGrant.issue_for!(
            user: current_user,
            callback_url: authorization_params.fetch(:callback_url),
            device_label: authorization_params[:device_label]
          )

          render json: {
            data: {
              redirect_url: redirect_url_for(grant.callback_url, code, authorization_params.fetch(:state))
            }
          }, status: :created
        end

        def token
          issued = McpBrowserAuthGrant.redeem!(code: token_params.fetch(:code))

          render json: {
            data: Api::V1::Serializers.mobile_auth_session(
              issued.fetch(:session),
              access_token: issued.fetch(:access_token),
              refresh_token: issued.fetch(:refresh_token)
            )
          }
        rescue McpBrowserAuthGrant::InvalidGrantError => error
          render json: { errors: [error.message] }, status: :unauthorized
        end

        private

        def authorization_params
          permitted = params.require(:authorization).permit(:callback_url, :state, :device_label)
          %i[callback_url state].each do |key|
            raise ActionController::ParameterMissing, key if permitted[key].blank?
          end
          permitted
        end

        def token_params
          permitted = params.require(:authorization).permit(:code)
          raise ActionController::ParameterMissing, :code if permitted[:code].blank?

          permitted
        end

        def redirect_url_for(callback_url, code, state)
          uri = URI.parse(callback_url)
          query = URI.decode_www_form(uri.query.to_s)
          query << ["code", code]
          query << ["state", state]
          uri.query = URI.encode_www_form(query)
          uri.to_s
        end
      end
    end
  end
end
