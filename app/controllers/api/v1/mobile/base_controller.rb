module Api
  module V1
    module Mobile
      class BaseController < ApplicationController
        before_action :ensure_json_request

        private

        def ensure_json_request
          request.format = :json
        end

        def authenticate_mobile_session!
          return if current_mobile_user.present?

          render json: { errors: ["Não autorizado"] }, status: :unauthorized
        end
      end
    end
  end
end
